#!/usr/bin/env -S uv run --script
# /// script
# requires-python = ">=3.10"
# dependencies = [
#   "beautifulsoup4",
#   "click",
#   "requests",
#   "playwright",
# ]
# ///
"""
Canary Custom Webroot Cloner
=============================
Clones a target internal web server into the correct format for uploading
as a Thinkst Canary custom webroot.

Output: a folder (and optional zip) containing:
  - index.html  (and any other HTML pages discovered)
  - CSS / JS / images referenced by those pages
  - .posted files so POST submissions show a realistic response
  - 403.html / 404.html error pages
  - thinkst-canary-metadata/config.toml (minimal)

Usage:
    ./canary_webroot_cloner.py https://10.0.0.50
    ./canary_webroot_cloner.py https://10.0.0.50 --depth 2 --output my_webroot --zip

    # For SPAs (React, Vue, Svelte, etc.) that render via client-side JS:
    ./canary_webroot_cloner.py http://192.168.1.50:8080 --headless

Requirements:
    Dependencies installed inline with uv.

    If using --headless:
        uv run --with playwright python -m playwright install chromium
"""

import os
import re
import shutil
import sys
import zipfile
from pathlib import Path
from urllib.parse import unquote, urljoin, urlparse

import click
import requests
from bs4 import BeautifulSoup
from playwright.sync_api import Error as PlaywrightError
from playwright.sync_api import Response, sync_playwright


def normalise_path(url: str, base_netloc: str) -> str | None:
    """Return a local file path for *url* if it belongs to the target site,
    otherwise None."""
    parsed = urlparse(url)
    if parsed.netloc and parsed.netloc != base_netloc:
        return None
    path = unquote(parsed.path).lstrip("/")
    if not path or path.endswith("/"):
        path = path + "index.html"
    return path


def sanitise_filename(path: str) -> str:
    """Replace characters that are problematic in some ZIP entries."""
    return re.sub(r'[<>:"|?*]', "_", path)


def build_browser_like_headers() -> dict[str, str]:
    return {
        "User-Agent": (
            "Mozilla/5.0 (Windows NT 10.0; Win64; x64) "
            "AppleWebKit/537.36 (KHTML, like Gecko) "
            "Chrome/125.0.0.0 Safari/537.36"
        ),
    }


def disable_insecure_request_warnings() -> None:
    import urllib3

    urllib3.disable_warnings(urllib3.exceptions.InsecureRequestWarning)


class BaseSiteCloner:
    def __init__(
        self,
        base_url: str,
        output_dir: str,
        verify_ssl: bool = False,
        timeout: int = 15,
    ):
        self.base_url = base_url.rstrip("/")
        self.base_netloc = urlparse(self.base_url).netloc
        self.output_dir = Path(output_dir)
        self.verify_ssl = verify_ssl
        self.timeout = timeout

        self.html_pages: list[str] = []
        self.downloaded_assets: set[str] = set()

        self._captured_403_html: str | None = None
        self._captured_404_html: str | None = None
        self._404_redirect_url: str | None = None

    @property
    def probe_session(self) -> requests.Session | None:
        raise NotImplementedError

    def _clone_site(self) -> None:
        raise NotImplementedError

    def _banner_lines(self) -> list[str]:
        return []

    def _prepare_output_dir(self) -> None:
        if self.output_dir.exists():
            shutil.rmtree(self.output_dir)
        self.output_dir.mkdir(parents=True)

    def _print_banner(self) -> None:
        click.echo(f"\n{'=' * 60}")
        click.echo(f"Cloning {self.base_url} → {self.output_dir}/")
        for line in self._banner_lines():
            click.echo(line)
        click.echo(f"{'=' * 60}\n")

    def _print_summary(self) -> None:
        click.echo(f"\n{'=' * 60}")
        click.echo(
            f"Done. {len(self.html_pages)} page(s), "
            f"{len(self.downloaded_assets)} asset(s) saved."
        )
        click.echo(f"Output directory: {self.output_dir}")
        click.echo(f"{'=' * 60}\n")

    def clone(self) -> None:
        """Run the full cloning pipeline."""
        self._prepare_output_dir()
        self._print_banner()

        if not self.verify_ssl:
            disable_insecure_request_warnings()

        self._clone_site()

        if not self.html_pages:
            click.echo(
                "\n[!] No HTML pages were downloaded. Check the URL and try again."
            )
            return

        self._probe_error_pages()
        self.generate_posted_files()
        self.generate_error_pages()
        self.generate_config()
        self._print_summary()

    def _probe_error_pages(self) -> None:
        """Probe the site with a guaranteed-nonexistent path to capture the
        real 404 response (or detect if 404s redirect elsewhere)."""
        session = self.probe_session
        if session is None:
            return

        probe_url = f"{self.base_url}/canary-probe-404-xyz123abc"
        click.echo(f"[probe] GET {probe_url}")
        try:
            resp = session.get(
                probe_url,
                timeout=self.timeout,
                allow_redirects=False,
            )
            if resp.status_code == 404:
                click.echo("  [404] Captured real 404 page")
                self._captured_404_html = resp.text
            elif resp.status_code in (301, 302, 303, 307, 308):
                location = resp.headers.get("Location", "")
                clean_location = (
                    urlparse(location)._replace(query="", fragment="").geturl()
                )
                click.echo(f"  [404→redirect] {resp.status_code} → {clean_location}")
                self._404_redirect_url = clean_location
            elif resp.status_code == 200:
                click.echo(
                    "  [404→200] Site returns 200 for unknown paths (SPA catch-all)"
                )
                self._captured_404_html = resp.text
            else:
                click.echo(f"  [probe] Unexpected status {resp.status_code}")
        except requests.RequestException as exc:
            click.echo(f"  [!] 404 probe failed: {exc}")

    def generate_posted_files(self) -> None:
        """For every HTML page that contains a <form>, create a matching
        .posted file so the Canary returns a realistic failed-login response
        after capturing POST data."""
        for local_path in self.html_pages:
            full = self.output_dir / local_path
            if not full.exists():
                continue
            page_text = full.read_text(encoding="utf-8", errors="replace")
            soup = BeautifulSoup(page_text, "html.parser")
            forms = soup.find_all("form")
            if not forms:
                continue

            posted_path = full.parent / (full.name + ".posted")
            posted_soup = BeautifulSoup(page_text, "html.parser")

            html_tag = posted_soup.find("html")
            classes = html_tag.get("class", []) if html_tag else []
            is_dark = "dark" in classes

            if is_dark:
                error_style = (
                    "color:#fca5a5;"
                    "padding:8px 12px;"
                    "margin-bottom:8px;"
                    "border:1px solid rgba(220,38,38,0.5);"
                    "border-radius:6px;"
                    "background:rgba(220,38,38,0.15);"
                    "font-size:0.875rem;"
                )
            else:
                error_style = (
                    "color:#b91c1c;"
                    "padding:8px 12px;"
                    "margin-bottom:8px;"
                    "border:1px solid #fca5a5;"
                    "border-radius:6px;"
                    "background:#fef2f2;"
                    "font-size:0.875rem;"
                )

            form_tag = posted_soup.find("form")
            if form_tag:
                error_div = posted_soup.new_tag("div", style=error_style)
                error_div.string = "Invalid username or password."
                form_tag.insert(0, error_div)

            posted_path.write_text(str(posted_soup), encoding="utf-8")
            click.echo(
                f"[posted] {posted_path.name}  ({'dark' if is_dark else 'light'} theme)"
            )

    def generate_error_pages(self) -> None:
        """Write 403.html and 404.html, preferring real captured responses."""
        for code, title, captured in [
            ("403", "Forbidden", self._captured_403_html),
            ("404", "Not Found", self._captured_404_html),
        ]:
            fname = f"{code}.html"
            dest = self.output_dir / fname
            if dest.exists():
                continue
            if captured:
                dest.write_text(captured, encoding="utf-8")
                click.echo(f"[error page] {fname}  (real site response)")
            elif code == "404" and self._404_redirect_url:
                dest.write_text(
                    f"<!DOCTYPE html>\n<html><head>"
                    f'<meta http-equiv="refresh" content="0;url=/index.html"/>'
                    f"<title>{code} {title}</title></head>"
                    f"<body></body></html>\n",
                    encoding="utf-8",
                )
                redirect_path = urlparse(self._404_redirect_url).path
                click.echo(
                    f"[error page] {fname}  "
                    f'(meta-refresh → index.html; "{redirect_path}" redirect added to config.toml)'
                )
            else:
                dest.write_text(
                    f"<!DOCTYPE html>\n<html><head><title>{code} {title}</title></head>\n"
                    f"<body><h1>{code} {title}</h1>"
                    f"<p>The requested resource is {title.lower()}.</p>"
                    f"</body></html>\n",
                    encoding="utf-8",
                )
                click.echo(f"[error page] {fname}  (generic fallback)")

    def generate_config(self) -> None:
        """Write a thinkst-canary-metadata/config.toml.

        Per-page sections set response_code = 200 for any page that has a
        .posted file, so the browser receives a 200 (not 403) after the Canary
        captures the submitted credentials.
        """
        meta_dir = self.output_dir / "thinkst-canary-metadata"
        meta_dir.mkdir(exist_ok=True)

        lines = ["# Auto-generated Canary custom webroot config", ""]

        lines.append("[redirects]")
        if self._404_redirect_url:
            redirect_path = urlparse(self._404_redirect_url).path
            if redirect_path and redirect_path.strip("/"):
                lines.append(f'"{redirect_path}" = "index.html"')
        lines.append("")

        for local_path in self.html_pages:
            full = self.output_dir / local_path
            if not full.exists():
                continue
            posted = full.parent / (full.name + ".posted")
            if not posted.exists():
                continue
            lines.append(f'["{local_path}"]')
            lines.append("response_code = 200")
            lines.append("")

        config_path = meta_dir / "config.toml"
        config_path.write_text("\n".join(lines) + "\n", encoding="utf-8")
        click.echo("[config] thinkst-canary-metadata/config.toml")

    def make_zip(self) -> Path:
        zip_path = self.output_dir.with_suffix(".zip")
        with zipfile.ZipFile(zip_path, "w", zipfile.ZIP_DEFLATED) as zf:
            for file in sorted(self.output_dir.rglob("*")):
                if file.is_file():
                    zf.write(file, file.relative_to(self.output_dir))
        click.echo(
            f"[zip] Created {zip_path}  ({zip_path.stat().st_size / 1024:.1f} KB)"
        )
        return zip_path


class RequestsSiteCloner(BaseSiteCloner):
    def __init__(
        self,
        base_url: str,
        output_dir: str,
        depth: int = 1,
        verify_ssl: bool = False,
        timeout: int = 15,
    ):
        super().__init__(
            base_url=base_url,
            output_dir=output_dir,
            verify_ssl=verify_ssl,
            timeout=timeout,
        )
        self.depth = depth

        self.session = requests.Session()
        self.session.verify = verify_ssl
        self.session.headers.update(build_browser_like_headers())

        self.visited_pages: set[str] = set()

    @property
    def probe_session(self) -> requests.Session | None:
        return self.session

    def _banner_lines(self) -> list[str]:
        return [f"Crawl depth: {self.depth}"]

    def _get(self, url: str) -> requests.Response | None:
        try:
            resp = self.session.get(url, timeout=self.timeout)
            if resp.status_code == 403 and self._captured_403_html is None:
                click.echo(f"  [403] Captured error page from {url}")
                self._captured_403_html = resp.text
            resp.raise_for_status()
            return resp
        except requests.RequestException as exc:
            click.echo(f"  [!] Failed to fetch {url}: {exc}")
            return None

    def _download_asset(self, url: str) -> str | None:
        """Download a single asset (css/js/img/font) and return its local path."""
        local = normalise_path(url, self.base_netloc)
        if local is None:
            return None
        local = sanitise_filename(local)
        if local in self.downloaded_assets:
            return local
        self.downloaded_assets.add(local)

        full_url = urljoin(self.base_url + "/", url)
        resp = self._get(full_url)
        if resp is None:
            return None

        dest = self.output_dir / local
        dest.parent.mkdir(parents=True, exist_ok=True)
        dest.write_bytes(resp.content)
        click.echo(f"  [asset] {local}")
        return local

    def _rewrite_and_save(self, html: str, url: str, local_path: str) -> None:
        """Parse *html*, download referenced assets, rewrite links to be
        relative, and save the result."""
        soup = BeautifulSoup(html, "html.parser")

        asset_tags = [
            ("link", "href"),
            ("script", "src"),
            ("img", "src"),
            ("source", "src"),
            ("source", "srcset"),
            ("video", "src"),
            ("audio", "src"),
            ("input", "src"),
        ]

        for tag_name, attr in asset_tags:
            for tag in soup.find_all(tag_name):
                raw = tag.get(attr)
                if not raw or raw.startswith("data:"):
                    continue
                absolute = urljoin(url + "/", raw)
                saved = self._download_asset(absolute)
                if saved:
                    html_dir = str(Path(local_path).parent)
                    if html_dir == ".":
                        tag[attr] = saved
                    else:
                        tag[attr] = os.path.relpath(saved, html_dir)

        for style_tag in soup.find_all("style"):
            if style_tag.string:
                style_tag.string = self._rewrite_css_urls(
                    style_tag.string, url, local_path
                )

        for tag in soup.find_all(style=True):
            tag["style"] = self._rewrite_css_urls(tag["style"], url, local_path)

        dest = self.output_dir / local_path
        dest.parent.mkdir(parents=True, exist_ok=True)
        dest.write_text(str(soup), encoding="utf-8")

    def _rewrite_css_urls(
        self, css_text: str, page_url: str, local_html_path: str
    ) -> str:
        """Find url(...) in CSS text, download assets, rewrite paths."""

        def _replace(match):
            raw = match.group(1).strip("'\"")
            if raw.startswith("data:"):
                return match.group(0)
            absolute = urljoin(page_url, raw)
            saved = self._download_asset(absolute)
            if saved:
                html_dir = str(Path(local_html_path).parent)
                rel = os.path.relpath(saved, html_dir) if html_dir != "." else saved
                return f"url('{rel}')"
            return match.group(0)

        return re.sub(r"url\(([^)]+)\)", _replace, css_text)

    def _crawl_page(self, url: str, current_depth: int) -> None:
        """Fetch an HTML page, save it, and optionally follow links."""
        canon = urlparse(url)._replace(fragment="").geturl()
        if canon in self.visited_pages:
            return
        self.visited_pages.add(canon)

        resp = self._get(url)
        if resp is None:
            return
        content_type = resp.headers.get("Content-Type", "")
        if "html" not in content_type:
            return

        local_path = normalise_path(url, self.base_netloc) or "index.html"
        local_path = sanitise_filename(local_path)
        self.html_pages.append(local_path)
        click.echo(f"[page] {local_path}  (depth {current_depth})")

        self._rewrite_and_save(resp.text, url, local_path)

        soup = BeautifulSoup(resp.text, "html.parser")
        for link in soup.find_all("link", rel="stylesheet"):
            href = link.get("href")
            if href:
                css_url = urljoin(url + "/", href)
                css_local = normalise_path(css_url, self.base_netloc)
                if css_local and css_local in self.downloaded_assets:
                    css_path = self.output_dir / sanitise_filename(css_local)
                    if css_path.exists():
                        rewritten = self._rewrite_css_urls(
                            css_path.read_text(encoding="utf-8", errors="replace"),
                            css_url,
                            css_local,
                        )
                        css_path.write_text(rewritten, encoding="utf-8")

        if current_depth < self.depth:
            for a_tag in soup.find_all("a", href=True):
                link_url = urljoin(url + "/", a_tag["href"])
                if urlparse(link_url).netloc == self.base_netloc:
                    self._crawl_page(link_url, current_depth + 1)

    def _clone_site(self) -> None:
        self._crawl_page(self.base_url, 0)


class HeadlessSiteCloner(BaseSiteCloner):
    """Uses Playwright to render JS-heavy SPAs before saving assets.

    After the page reaches network-idle, it captures the live DOM, downloads
    every resource that the browser actually loaded, strips <script> tags
    (optional), and saves a static replica.
    """

    def __init__(
        self,
        base_url: str,
        output_dir: str,
        strip_js: bool = True,
        verify_ssl: bool = False,
        timeout: int = 30,
    ):
        super().__init__(
            base_url=base_url,
            output_dir=output_dir,
            verify_ssl=verify_ssl,
            timeout=timeout,
        )
        self.strip_js = strip_js
        self.playwright_timeout = timeout * 1000

        self._captured_resources: dict[str, bytes] = {}
        self._session: requests.Session | None = None

    @property
    def probe_session(self) -> requests.Session | None:
        return self._session

    def _banner_lines(self) -> list[str]:
        return [
            "[headless] Rendering with Chromium",
            f"Strip JS: {self.strip_js}",
        ]

    def _intercept_response(self, response: Response) -> None:
        """Store every response body so we can save assets without re-fetching."""
        try:
            ct = response.headers.get("content-type", "")
            if "html" not in ct:
                self._captured_resources[response.url] = response.body()
        except Exception:
            pass

    def _download_asset(self, url: str, session: requests.Session) -> str | None:
        local = normalise_path(url, self.base_netloc)
        if local is None:
            return None
        local = sanitise_filename(local)
        if local in self.downloaded_assets:
            return local
        self.downloaded_assets.add(local)

        content = self._captured_resources.get(url)
        if content is None:
            try:
                resp = session.get(url, timeout=15, verify=self.verify_ssl)
                resp.raise_for_status()
                content = resp.content
            except Exception as exc:
                click.echo(f"  [!] Failed to fetch {url}: {exc}")
                return None

        dest = self.output_dir / local
        dest.parent.mkdir(parents=True, exist_ok=True)
        dest.write_bytes(content)
        click.echo(f"  [asset] {local}")
        return local

    def _rewrite_css_urls(
        self,
        css_text: str,
        css_url: str,
        local_css_path: str,
        session: requests.Session,
    ) -> str:
        css_dir = str(Path(local_css_path).parent)

        def _replace_url(match: re.Match[str]) -> str:
            raw = match.group(1).strip("'\"")
            if raw.startswith("data:"):
                return match.group(0)
            absolute = urljoin(css_url, raw)
            saved = self._download_asset(absolute, session)
            if saved:
                rel = os.path.relpath(saved, css_dir) if css_dir != "." else saved
                return f"url('{rel}')"
            return match.group(0)

        def _replace_import(match: re.Match[str]) -> str:
            raw = match.group(1).strip("'\"")
            if raw.startswith("data:") or raw.startswith("http"):
                return match.group(0)
            absolute = urljoin(css_url, raw)
            saved = self._download_asset(absolute, session)
            if saved:
                rel = os.path.relpath(saved, css_dir) if css_dir != "." else saved
                return f"@import '{rel}'"
            return match.group(0)

        css_text = re.sub(r"url\(([^)]+)\)", _replace_url, css_text)
        css_text = re.sub(r"""@import\s+['"]([^'"]+)['"]""", _replace_import, css_text)
        return css_text

    def _process_html(
        self, html: str, local_path: str, session: requests.Session
    ) -> None:
        soup = BeautifulSoup(html, "html.parser")

        if self.strip_js:
            for s in soup.find_all("script"):
                s.decompose()

        asset_tags = [
            ("link", "href"),
            ("img", "src"),
            ("source", "src"),
            ("video", "src"),
            ("audio", "src"),
            ("input", "src"),
        ]
        if not self.strip_js:
            asset_tags.append(("script", "src"))

        asset_base = self.base_url + "/"

        for tag_name, attr in asset_tags:
            for tag in soup.find_all(tag_name):
                raw = tag.get(attr)
                if not raw or raw.startswith("data:"):
                    continue
                absolute = urljoin(asset_base, raw)
                saved = self._download_asset(absolute, session)
                if saved:
                    html_dir = str(Path(local_path).parent)
                    tag[attr] = (
                        saved if html_dir == "." else os.path.relpath(saved, html_dir)
                    )

        for style_tag in soup.find_all("style"):
            if style_tag.string:
                style_tag.string = self._rewrite_css_urls(
                    style_tag.string, asset_base, local_path, session
                )

        for tag in soup.find_all(style=True):
            tag["style"] = self._rewrite_css_urls(
                tag["style"], asset_base, local_path, session
            )

        for form in soup.find_all("form"):
            if not form.get("method"):
                form["method"] = "post"

        dest = self.output_dir / local_path
        dest.parent.mkdir(parents=True, exist_ok=True)
        dest.write_text(str(soup), encoding="utf-8")

    def _save_intercepted_resources(self) -> None:
        click.echo("[browser] Saving all intercepted browser resources...")
        for res_url, content in self._captured_resources.items():
            res_local = normalise_path(res_url, self.base_netloc)
            if res_local is None:
                continue
            res_local = sanitise_filename(res_local)
            if res_local in self.downloaded_assets:
                continue
            self.downloaded_assets.add(res_local)
            dest = self.output_dir / res_local
            dest.parent.mkdir(parents=True, exist_ok=True)
            dest.write_bytes(content)
            click.echo(f"  [asset] {res_local}")

    def _rewrite_downloaded_css_files(self, session: requests.Session) -> None:
        for asset_local in list(self.downloaded_assets):
            if asset_local.endswith(".css"):
                css_path = self.output_dir / asset_local
                if css_path.exists():
                    css_url = urljoin(self.base_url + "/", asset_local)
                    rewritten = self._rewrite_css_urls(
                        css_path.read_text(encoding="utf-8", errors="replace"),
                        css_url,
                        asset_local,
                        session,
                    )
                    css_path.write_text(rewritten, encoding="utf-8")

    def _clone_site(self) -> None:
        self._session = requests.Session()
        self._session.verify = self.verify_ssl
        self._session.headers.update(build_browser_like_headers())
        session = self._session

        try:
            with sync_playwright() as p:
                browser = p.chromium.launch(headless=True)
                ctx = browser.new_context(
                    ignore_https_errors=True,
                    color_scheme="dark",
                )
                page = ctx.new_page()

                page.on("response", self._intercept_response)

                click.echo(f"[browser] Navigating to {self.base_url} ...")
                page.goto(
                    self.base_url,
                    wait_until="networkidle",
                    timeout=self.playwright_timeout,
                )

                final_url = page.url
                click.echo(f"[browser] Final URL: {final_url}")

                page.evaluate("""
                    () => {
                        for (const sheet of document.styleSheets) {
                            try {
                                if (sheet.href) continue;
                                const rules = Array.from(sheet.cssRules || [])
                                    .map(r => r.cssText).join('\\n');
                                if (sheet.ownerNode && rules) {
                                    sheet.ownerNode.textContent = rules;
                                }
                            } catch (e) { /* cross-origin sheet — skip */ }
                        }
                    }
                """)

                rendered_html = page.content()
                browser.close()
        except PlaywrightError as exc:
            if "Please run the following command to download new browsers" in str(exc):
                sys.exit(
                    "Playwright browser binaries are not installed. To install them, run: \n"
                    "  uv run --with playwright python -m playwright install chromium"
                )
            raise

        local_path = "index.html"
        self.html_pages.append(local_path)
        click.echo(f"[page] {local_path}")

        self._save_intercepted_resources()
        self._process_html(rendered_html, local_path, session)
        self._rewrite_downloaded_css_files(session)


@click.command(help="Clone an internal website into a Thinkst Canary custom webroot.")
@click.argument("url")
@click.option(
    "-o",
    "--output",
    default="canary_webroot",
    help="Output directory name (default: canary_webroot)",
)
@click.option(
    "-d",
    "--depth",
    type=int,
    default=1,
    help="How many levels of links to follow (default: 1)",
)
@click.option(
    "-z",
    "--zip",
    "make_zip",
    is_flag=True,
    help="Also produce a .zip file ready for upload",
)
@click.option(
    "--verify-ssl",
    is_flag=True,
    help="Verify SSL certificates (default: off for internal servers)",
)
@click.option(
    "--timeout",
    type=int,
    default=15,
    help="HTTP request timeout in seconds (default: 15)",
)
@click.option(
    "--headless",
    is_flag=True,
    help="Use headless Chromium for JS-rendered SPAs. Requires: uv run --with playwright python -m playwright install chromium",
)
@click.option(
    "--keep-js",
    is_flag=True,
    help="Keep <script> tags (stripped by default in headless mode)",
)
def main(
    url=None,
    output="canary_webroot",
    depth=1,
    make_zip=False,
    verify_ssl=False,
    timeout=15,
    headless=False,
    keep_js=False,
):
    if url is None:
        raise click.UsageError("URL is required")

    strip_js = not keep_js

    if headless:
        cloner = HeadlessSiteCloner(
            base_url=url,
            output_dir=output,
            strip_js=strip_js,
            verify_ssl=verify_ssl,
            timeout=timeout,
        )
    else:
        cloner = RequestsSiteCloner(
            base_url=url,
            output_dir=output,
            depth=depth,
            verify_ssl=verify_ssl,
            timeout=timeout,
        )

    cloner.clone()

    if make_zip:
        cloner.make_zip()

    click.echo("Next steps:")
    click.echo("  1. Review the output folder and tweak as needed")
    click.echo("  2. Zip the folder (or use --zip) and upload via your")
    click.echo("     Canary Console → Configure Canary → HTTP Web Server")
    click.echo("     → Upload custom webroot")
    click.echo("  3. Set HTTP Page Skin to 'User Supplied' and deploy\n")


if __name__ == "__main__":
    main()
