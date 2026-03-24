#!/usr/bin/env -S uv run --script
# /// script
# requires-python = ">=3.10"
# dependencies = [
#   "beautifulsoup4",
#   "click",
#   "requests",
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
    python canary_webroot_cloner.py https://10.0.0.50
    python canary_webroot_cloner.py https://10.0.0.50 --depth 2 --output my_webroot --zip

    # For SPAs (React, Vue, Svelte, etc.) that render via client-side JS:
    python canary_webroot_cloner.py http://192.168.1.50:8080 --headless

Requirements (stdlib only except for common libs):
    uv pip install -r requirements.txt
    playwright install chromium   # only for --headless
"""

import click
import os
import re
import shutil
import sys
import zipfile
from pathlib import Path
from urllib.parse import urljoin, urlparse, unquote

try:
    import requests
    from bs4 import BeautifulSoup
except ImportError:
    sys.exit(
        "Missing dependencies. Install them with:\n"
        "  pip install requests beautifulsoup4"
    )

try:
    from playwright.sync_api import sync_playwright
    PLAYWRIGHT_AVAILABLE = True
except ImportError:
    PLAYWRIGHT_AVAILABLE = False

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

def normalise_path(url: str, base_netloc: str) -> str | None:
    """Return a local file path for *url* if it belongs to the target site,
    otherwise None."""
    parsed = urlparse(url)
    # Skip off-site resources
    if parsed.netloc and parsed.netloc != base_netloc:
        return None
    path = unquote(parsed.path).lstrip("/")
    if not path or path.endswith("/"):
        path = path + "index.html"
    return path


def sanitise_filename(path: str) -> str:
    """Replace characters that are problematic in some ZIP entries"""
    return re.sub(r'[<>:"|?*]', "_", path)


# ---------------------------------------------------------------------------
# Downloader
# ---------------------------------------------------------------------------

class HeadlessSiteCloner:
    """Uses Playwright to render JS-heavy SPAs before saving assets.

    After the page reaches network-idle, it captures the live DOM, downloads
    every resource that the browser actually loaded, strips <script> tags
    (optional), and saves a static replica.
    """

    def __init__(self, base_url: str, output_dir: str, strip_js: bool = True,
                 verify_ssl: bool = False, timeout: int = 30):
        if not PLAYWRIGHT_AVAILABLE:
            sys.exit(
                "Playwright is not installed. Install it with:\n"
                "  pip install playwright && playwright install chromium"
            )
        self.base_url = base_url.rstrip("/")
        self.base_netloc = urlparse(self.base_url).netloc
        self.output_dir = Path(output_dir)
        self.strip_js = strip_js
        self.verify_ssl = verify_ssl
        self.timeout = timeout * 1000  # Playwright uses ms

        self.html_pages: list[str] = []
        self.downloaded_assets: set[str] = set()
        self._captured_resources: dict[str, bytes] = {}  # url -> content

        self._captured_403_html: str | None = None
        self._captured_404_html: str | None = None
        self._404_redirect_url: str | None = None
        self._session: requests.Session | None = None

    def _intercept_response(self, response):
        """Store every response body so we can save assets without re-fetching."""
        try:
            ct = response.headers.get("content-type", "")
            if "html" not in ct:
                self._captured_resources[response.url] = response.body()
        except Exception:
            pass  # body() can fail for certain resource types

    def _download_asset(self, url: str, session: requests.Session) -> str | None:
        local = normalise_path(url, self.base_netloc)
        if local is None:
            return None
        local = sanitise_filename(local)
        if local in self.downloaded_assets:
            return local
        self.downloaded_assets.add(local)

        # Use captured body if available, otherwise fall back to requests
        content = self._captured_resources.get(url)
        if content is None:
            try:
                resp = session.get(url, timeout=15, verify=self.verify_ssl)
                resp.raise_for_status()
                content = resp.content
            except Exception as exc:
                print(f"  [!] Failed to fetch {url}: {exc}")
                return None

        dest = self.output_dir / local
        dest.parent.mkdir(parents=True, exist_ok=True)
        dest.write_bytes(content)
        print(f"  [asset] {local}")
        return local

    def _rewrite_css_urls(self, css_text: str, css_url: str,
                          local_css_path: str, session: requests.Session) -> str:
        css_dir = str(Path(local_css_path).parent)

        def _replace_url(match):
            raw = match.group(1).strip("'\"")
            if raw.startswith("data:"):
                return match.group(0)
            absolute = urljoin(css_url, raw)
            saved = self._download_asset(absolute, session)
            if saved:
                rel = os.path.relpath(saved, css_dir) if css_dir != "." else saved
                return f"url('{rel}')"
            return match.group(0)

        def _replace_import(match):
            # Handle bare @import 'file.css' / @import "file.css" (no url())
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

    def _process_html(self, html: str, local_path: str,
                      session: requests.Session):
        soup = BeautifulSoup(html, "html.parser")

        # Remove <script> tags if requested
        if self.strip_js:
            for s in soup.find_all("script"):
                s.decompose()

        asset_tags = [
            ("link",   "href"),
            ("img",    "src"),
            ("source", "src"),
            ("video",  "src"),
            ("audio",  "src"),
            ("input",  "src"),
        ]
        if not self.strip_js:
            asset_tags.append(("script", "src"))

        # SPA assets are always root-relative regardless of the current page path
        # (e.g. final URL may be /auth but assets are at /_app/...).
        # Use base_url as the resolution base to avoid off-by-one path errors.
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
                    tag[attr] = saved if html_dir == "." else os.path.relpath(saved, html_dir)

        # Inline style blocks
        for style_tag in soup.find_all("style"):
            if style_tag.string:
                style_tag.string = self._rewrite_css_urls(
                    style_tag.string, asset_base, local_path, session
                )

        for tag in soup.find_all(style=True):
            tag["style"] = self._rewrite_css_urls(
                tag["style"], asset_base, local_path, session
            )

        # Ensure all forms use POST — JS-driven forms often omit the method
        # attribute entirely, which causes browsers to default to GET.
        for form in soup.find_all("form"):
            if not form.get("method"):
                form["method"] = "post"

        dest = self.output_dir / local_path
        dest.parent.mkdir(parents=True, exist_ok=True)
        dest.write_text(str(soup), encoding="utf-8")

    def clone(self):
        if self.output_dir.exists():
            shutil.rmtree(self.output_dir)
        self.output_dir.mkdir(parents=True)

        print(f"\n{'='*60}")
        print(f"[headless] Cloning {self.base_url} → {self.output_dir}/")
        print(f"Strip JS: {self.strip_js}")
        print(f"{'='*60}\n")

        self._session = requests.Session()
        self._session.verify = self.verify_ssl
        self._session.headers.update({
            "User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) "
                          "AppleWebKit/537.36 (KHTML, like Gecko) "
                          "Chrome/125.0.0.0 Safari/537.36",
        })
        session = self._session  # local alias for use below

        if not self.verify_ssl:
            import urllib3
            urllib3.disable_warnings(urllib3.exceptions.InsecureRequestWarning)

        with sync_playwright() as p:
            browser = p.chromium.launch(headless=True)
            ctx = browser.new_context(
                ignore_https_errors=True,
                color_scheme="dark",  # ensure dark-mode SPAs render with dark theme
            )
            page = ctx.new_page()

            # Capture every response body for later asset saving
            page.on("response", self._intercept_response)

            print(f"[browser] Navigating to {self.base_url} ...")
            page.goto(self.base_url, wait_until="networkidle",
                      timeout=self.timeout)

            # The browser may have been redirected (e.g. /auth) — capture final URL
            final_url = page.url
            print(f"[browser] Final URL: {final_url}")

            # CSS-in-JS libraries (emotion, styled-components) inject rules via
            # sheet.insertRule() which is invisible to page.content().
            # Serialize all CSSOM rules back into their <style> tag textContent
            # so they survive the DOM snapshot.
            page.evaluate("""
                () => {
                    for (const sheet of document.styleSheets) {
                        try {
                            if (sheet.href) continue;  // skip external files
                            const rules = Array.from(sheet.cssRules || [])
                                .map(r => r.cssText).join('\\n');
                            if (sheet.ownerNode && rules) {
                                sheet.ownerNode.textContent = rules;
                            }
                        } catch (e) { /* cross-origin sheet — skip */ }
                    }
                }
            """)

            # Grab the fully rendered DOM (now with inline CSS populated)
            rendered_html = page.content()

            browser.close()

        # Always save the entry point as index.html so the Canary serves it
        local_path = "index.html"
        self.html_pages.append(local_path)
        print(f"[page] {local_path}")

        # Save every resource the browser loaded (fonts, CSS, images, etc.)
        # This covers assets found via @import, @font-face, and other paths
        # that HTML-tag scanning alone would miss.
        print("[browser] Saving all intercepted browser resources...")
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
            print(f"  [asset] {res_local}")

        # Process HTML: rewrite asset references to relative paths
        self._process_html(rendered_html, local_path, session)

        # Rewrite url() references inside every CSS file so paths stay relative
        for asset_local in list(self.downloaded_assets):
            if asset_local.endswith(".css"):
                css_path = self.output_dir / asset_local
                if css_path.exists():
                    css_url = urljoin(self.base_url + "/", asset_local)
                    rewritten = self._rewrite_css_urls(
                        css_path.read_text(encoding="utf-8", errors="replace"),
                        css_url, asset_local, session,
                    )
                    css_path.write_text(rewritten, encoding="utf-8")

        self._probe_error_pages()

        print(f"\n{'='*60}")
        print(f"Done. {len(self.html_pages)} page(s), "
              f"{len(self.downloaded_assets)} asset(s) saved.")
        print(f"Output directory: {self.output_dir}")
        print(f"{'='*60}\n")

    def make_zip(self) -> Path:
        zip_path = self.output_dir.with_suffix(".zip")
        with zipfile.ZipFile(zip_path, "w", zipfile.ZIP_DEFLATED) as zf:
            for file in sorted(self.output_dir.rglob("*")):
                if file.is_file():
                    zf.write(file, file.relative_to(self.output_dir))
        print(f"[zip] Created {zip_path}  "
              f"({zip_path.stat().st_size / 1024:.1f} KB)")
        return zip_path

    def _probe_error_pages(self):
        """Probe the site with a guaranteed-nonexistent path to capture the
        real 404 response (or detect if 404s redirect elsewhere)."""
        if self._session is None:
            return
        probe_url = f"{self.base_url}/canary-probe-404-xyz123abc"
        print(f"[probe] GET {probe_url}")
        try:
            resp = self._session.get(probe_url, timeout=15,
                                     allow_redirects=False)
            if resp.status_code == 404:
                print("  [404] Captured real 404 page")
                self._captured_404_html = resp.text
            elif resp.status_code in (301, 302, 303, 307, 308):
                location = resp.headers.get("Location", "")
                # Strip query string — it reflects our probe URL as a parameter
                # (e.g. /login?redirectTo=%2Fcanary-probe-...), not real content.
                clean_location = urlparse(location)._replace(query="", fragment="").geturl()
                print(f"  [404→redirect] {resp.status_code} → {clean_location}")
                self._404_redirect_url = clean_location
            elif resp.status_code == 200:
                print("  [404→200] Site returns 200 for unknown paths (SPA catch-all)")
                self._captured_404_html = resp.text
            else:
                print(f"  [probe] Unexpected status {resp.status_code}")
        except requests.RequestException as exc:
            print(f"  [!] 404 probe failed: {exc}")

    def _make_delegate(self) -> "SiteCloner":
        """Create a SiteCloner shell with our shared state for delegation."""
        d = SiteCloner.__new__(SiteCloner)
        d.output_dir = self.output_dir
        d.html_pages = self.html_pages
        d._captured_403_html = self._captured_403_html
        d._captured_404_html = self._captured_404_html
        d._404_redirect_url = self._404_redirect_url
        return d

    def generate_posted_files(self):
        SiteCloner.generate_posted_files(self._make_delegate())

    def generate_error_pages(self):
        SiteCloner.generate_error_pages(self._make_delegate())

    def generate_config(self):
        SiteCloner.generate_config(self._make_delegate())


class SiteCloner:
    def __init__(self, base_url: str, output_dir: str, depth: int = 1,
                 verify_ssl: bool = False, timeout: int = 15):
        self.base_url = base_url.rstrip("/")
        self.base_netloc = urlparse(self.base_url).netloc
        self.output_dir = Path(output_dir)
        self.depth = depth
        self.verify_ssl = verify_ssl
        self.timeout = timeout

        self.session = requests.Session()
        self.session.verify = verify_ssl
        self.session.headers.update({
            "User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) "
                          "AppleWebKit/537.36 (KHTML, like Gecko) "
                          "Chrome/125.0.0.0 Safari/537.36",
        })

        # Track what we've already fetched to avoid loops
        self.visited_pages: set[str] = set()
        self.downloaded_assets: set[str] = set()
        self.html_pages: list[str] = []  # local paths of HTML files

        # Captured real error responses for use in error page generation
        self._captured_403_html: str | None = None
        self._captured_404_html: str | None = None
        self._404_redirect_url: str | None = None  # set when 404 probe hits a redirect

    # ---- networking -------------------------------------------------------

    def _get(self, url: str) -> requests.Response | None:
        try:
            resp = self.session.get(url, timeout=self.timeout)
            if resp.status_code == 403 and self._captured_403_html is None:
                print(f"  [403] Captured error page from {url}")
                self._captured_403_html = resp.text
            resp.raise_for_status()
            return resp
        except requests.RequestException as exc:
            print(f"  [!] Failed to fetch {url}: {exc}")
            return None

    def _probe_error_pages(self):
        """Probe the site with a guaranteed-nonexistent path to capture the
        real 404 response (or detect if 404s redirect elsewhere)."""
        probe_url = f"{self.base_url}/canary-probe-404-xyz123abc"
        print(f"[probe] GET {probe_url}")
        try:
            resp = self.session.get(probe_url, timeout=self.timeout,
                                    allow_redirects=False)
            if resp.status_code == 404:
                print(f"  [404] Captured real 404 page")
                self._captured_404_html = resp.text
            elif resp.status_code in (301, 302, 303, 307, 308):
                location = resp.headers.get("Location", "")
                # Strip query string — it reflects our probe URL as a parameter
                # (e.g. /login?redirectTo=%2Fcanary-probe-...), not real content.
                clean_location = urlparse(location)._replace(query="", fragment="").geturl()
                print(f"  [404→redirect] {resp.status_code} → {clean_location}")
                self._404_redirect_url = clean_location
            elif resp.status_code == 200:
                # Site returns 200 for unknown paths (catch-all SPA routing)
                print(f"  [404→200] Site returns 200 for unknown paths (SPA catch-all)")
                self._captured_404_html = resp.text
            else:
                print(f"  [probe] Unexpected status {resp.status_code}")
        except requests.RequestException as exc:
            print(f"  [!] 404 probe failed: {exc}")

    # ---- asset downloading ------------------------------------------------

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
        print(f"  [asset] {local}")
        return local

    # ---- HTML rewriting ---------------------------------------------------

    def _rewrite_and_save(self, html: str, url: str, local_path: str):
        """Parse *html*, download referenced assets, rewrite links to be
        relative, and save the result."""
        soup = BeautifulSoup(html, "html.parser")

        # Tags and their URL-bearing attributes
        asset_tags = [
            ("link",   "href"),
            ("script", "src"),
            ("img",    "src"),
            ("source", "src"),
            ("source", "srcset"),
            ("video",  "src"),
            ("audio",  "src"),
            ("input",  "src"),
        ]

        for tag_name, attr in asset_tags:
            for tag in soup.find_all(tag_name):
                raw = tag.get(attr)
                if not raw or raw.startswith("data:"):
                    continue
                absolute = urljoin(url + "/", raw)
                saved = self._download_asset(absolute)
                if saved:
                    # Make the path relative to the HTML file's directory
                    html_dir = str(Path(local_path).parent)
                    if html_dir == ".":
                        tag[attr] = saved
                    else:
                        tag[attr] = os.path.relpath(saved, html_dir)

        # Also grab CSS url() references inside <style> blocks
        for style_tag in soup.find_all("style"):
            if style_tag.string:
                style_tag.string = self._rewrite_css_urls(
                    style_tag.string, url, local_path
                )

        # Inline style attributes with url(...)
        for tag in soup.find_all(style=True):
            tag["style"] = self._rewrite_css_urls(
                tag["style"], url, local_path
            )

        dest = self.output_dir / local_path
        dest.parent.mkdir(parents=True, exist_ok=True)
        dest.write_text(str(soup), encoding="utf-8")

    def _rewrite_css_urls(self, css_text: str, page_url: str,
                          local_html_path: str) -> str:
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

    # ---- page crawling ----------------------------------------------------

    def _crawl_page(self, url: str, current_depth: int):
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
        print(f"[page] {local_path}  (depth {current_depth})")

        self._rewrite_and_save(resp.text, url, local_path)

        # Download linked CSS files for their own url() assets
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
                            css_url, css_local,
                        )
                        css_path.write_text(rewritten, encoding="utf-8")

        # Follow same-site links up to max depth
        if current_depth < self.depth:
            for a_tag in soup.find_all("a", href=True):
                link_url = urljoin(url + "/", a_tag["href"])
                if urlparse(link_url).netloc == self.base_netloc:
                    self._crawl_page(link_url, current_depth + 1)

    # ---- .posted file generation -----------------------------------------

    def generate_posted_files(self):
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

            # Detect dark mode from the <html> element's class list
            html_tag = posted_soup.find("html")
            classes = html_tag.get("class", []) if html_tag else []
            is_dark = "dark" in classes

            # Style the error banner to match the page theme
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
            print(f"[posted] {posted_path.name}  ({'dark' if is_dark else 'light'} theme)")

    # ---- error pages ------------------------------------------------------

    def generate_error_pages(self):
        """Write 403.html and 404.html, preferring real captured responses."""
        for code, title, captured in [
            ("403", "Forbidden",  self._captured_403_html),
            ("404", "Not Found",  self._captured_404_html),
        ]:
            fname = f"{code}.html"
            dest = self.output_dir / fname
            if dest.exists():
                continue
            if captured:
                dest.write_text(captured, encoding="utf-8")
                print(f"[error page] {fname}  (real site response)")
            elif code == "404" and self._404_redirect_url:
                # Site redirects unknown paths to login — meta-refresh to our
                # saved index.html; the redirect path is also wired in config.toml.
                dest.write_text(
                    f'<!DOCTYPE html>\n<html><head>'
                    f'<meta http-equiv="refresh" content="0;url=/index.html"/>'
                    f'<title>{code} {title}</title></head>'
                    f'<body></body></html>\n',
                    encoding="utf-8",
                )
                redirect_path = urlparse(self._404_redirect_url).path
                print(f"[error page] {fname}  (meta-refresh → index.html; "
                      f'"{redirect_path}" redirect added to config.toml)')
            else:
                dest.write_text(
                    f"<!DOCTYPE html>\n<html><head><title>{code} {title}</title></head>\n"
                    f"<body><h1>{code} {title}</h1>"
                    f"<p>The requested resource is {title.lower()}.</p>"
                    f"</body></html>\n",
                    encoding="utf-8",
                )
                print(f"[error page] {fname}  (generic fallback)")

    # ---- config.toml ------------------------------------------------------

    def generate_config(self):
        """Write a thinkst-canary-metadata/config.toml.

        Per-page sections set response_code = 200 for any page that has a
        .posted file, so the browser receives a 200 (not 403) after the Canary
        captures the submitted credentials.
        """
        meta_dir = self.output_dir / "thinkst-canary-metadata"
        meta_dir.mkdir(exist_ok=True)

        lines = ["# Auto-generated Canary custom webroot config", ""]

        lines.append("[redirects]")
        # If the site redirects unknown paths to a login page, add that path
        # as a canary-native redirect so e.g. /login → index.html works too.
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
            # TOML section header — quote the key so dots/slashes are literal
            lines.append(f'["{local_path}"]')
            lines.append("response_code = 200")
            lines.append("")

        config_path = meta_dir / "config.toml"
        config_path.write_text("\n".join(lines) + "\n", encoding="utf-8")
        print(f"[config] thinkst-canary-metadata/config.toml")

    # ---- public entry point -----------------------------------------------

    def clone(self):
        """Run the full cloning pipeline."""
        if self.output_dir.exists():
            shutil.rmtree(self.output_dir)
        self.output_dir.mkdir(parents=True)

        print(f"\n{'='*60}")
        print(f"Cloning {self.base_url} → {self.output_dir}/")
        print(f"Crawl depth: {self.depth}")
        print(f"{'='*60}\n")

        # Suppress SSL warnings when verify is off
        if not self.verify_ssl:
            import urllib3
            urllib3.disable_warnings(urllib3.exceptions.InsecureRequestWarning)

        self._crawl_page(self.base_url, 0)

        if not self.html_pages:
            print("\n[!] No HTML pages were downloaded. Check the URL and try again.")
            return

        self._probe_error_pages()
        self.generate_posted_files()
        self.generate_error_pages()
        self.generate_config()

        print(f"\n{'='*60}")
        print(f"Done. {len(self.html_pages)} page(s), "
              f"{len(self.downloaded_assets)} asset(s) saved.")
        print(f"Output directory: {self.output_dir}")
        print(f"{'='*60}\n")

    def make_zip(self) -> Path:
        """Zip the output directory into a file ready for Canary upload."""
        zip_path = self.output_dir.with_suffix(".zip")
        with zipfile.ZipFile(zip_path, "w", zipfile.ZIP_DEFLATED) as zf:
            for file in sorted(self.output_dir.rglob("*")):
                if file.is_file():
                    arcname = file.relative_to(self.output_dir)
                    zf.write(file, arcname)
        print(f"[zip] Created {zip_path}  "
              f"({zip_path.stat().st_size / 1024:.1f} KB)")
        return zip_path


# ---------------------------------------------------------------------------
# CLI
# ---------------------------------------------------------------------------

@click.command(help="Clone an internal website into a Thinkst Canary custom webroot.")
@click.argument("url")
@click.option("-o", "--output", default="canary_webroot", help="Output directory name (default: canary_webroot)")
@click.option("-d", "--depth", type=int, default=1, help="How many levels of links to follow (default: 1)")
@click.option("-z", "--zip", "make_zip", is_flag=True, help="Also produce a .zip file ready for upload")
@click.option("--verify-ssl", is_flag=True, help="Verify SSL certificates (default: off for internal servers)")
@click.option("--timeout", type=int, default=15, help="HTTP request timeout in seconds (default: 15)")
@click.option("--headless", is_flag=True, help="Use headless Chromium for JS-rendered SPAs. Requires: playwright install chromium")
@click.option("--keep-js", is_flag=True, help="Keep <script> tags (stripped by default in headless mode)")
def main(url, output, depth, make_zip, verify_ssl, timeout, headless, keep_js):
    strip_js = not keep_js  # default strip; --keep-js disables it

    if headless:
        cloner = HeadlessSiteCloner(
            base_url=url,
            output_dir=output,
            strip_js=strip_js,
            verify_ssl=verify_ssl,
            timeout=timeout,
        )
        cloner.clone()
        cloner.generate_posted_files()
        cloner.generate_error_pages()
        cloner.generate_config()
    else:
        cloner = SiteCloner(
            base_url=url,
            output_dir=output,
            depth=depth,
            verify_ssl=verify_ssl,
            timeout=timeout,
        )
        cloner.clone()

    if make_zip:
        cloner.make_zip()

    print("Next steps:")
    print("  1. Review the output folder and tweak as needed")
    print("  2. Zip the folder (or use --zip) and upload via your")
    print("     Canary Console → Configure Canary → HTTP Web Server")
    print("     → Upload custom webroot")
    print("  3. Set HTTP Page Skin to 'User Supplied' and deploy\n")


if __name__ == "__main__":
    main()