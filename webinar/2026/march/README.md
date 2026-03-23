# Canary Webroot Cloner

Clones an web application into a static folder ready for upload as a [Thinkst Canary](https://canary.tools/) custom webroot. The result is a convincing web server on your Bird that captures submitted credentials via POST without requiring any changes to your Canary configuration beyond uploading the zip as a custom webroot.

## What it produces

```
canary_webroot/
├── index.html                          # Cloned login page
├── index.html.posted                   # Shown after form submission (failed-login message)
├── static/                             # CSS, fonts, images, JS
├── _app/                               # SPA build assets (headless mode)
├── 403.html                            # Real or generated 403 error page
├── 404.html                            # Real, redirect, or generated 404 page
└── thinkst-canary-metadata/
    └── config.toml                     # Redirects + POST response codes
```

## Installation

```bash
uv pip install -r requirements.txt

# For --headless mode only (SPAs: React, Vue, Svelte, etc.)
playwright install chromium
```

## Usage

### Standard clone (server-rendered pages)

```bash
python canary_webroot_cloner.py https://10.0.0.50
```

### SPA / JS-rendered pages (recommended for most modern apps)

```bash
python canary_webroot_cloner.py http://192.168.1.50:8080 --headless
```

### Common options

| Flag | Default | Description |
|------|---------|-------------|
| `-o / --output` | `canary_webroot` | Output directory name |
| `-d / --depth` | `1` | Link-follow depth (standard mode only) |
| `-z / --zip` | off | Also produce a `.zip` ready for upload |
| `--headless` | off | Use headless Chromium for JS-rendered SPAs |
| `--keep-js` | off | Keep `<script>` tags (stripped by default in headless mode) |
| `--verify-ssl` | off | Verify SSL certificates |
| `--timeout` | `15` | HTTP timeout in seconds |

### Examples

```bash
# Grafana login page, output as zip
python canary_webroot_cloner.py http://grafana.internal:3000 --headless --zip

# Open WebUI with custom output directory
python canary_webroot_cloner.py https://openwebui.internal --headless -o openwebui_canary --zip

# Multi-page standard site, follow links 2 levels deep
python canary_webroot_cloner.py http://intranet.corp --depth 2 --zip
```

## How it works

### Headless mode (`--headless`)

1. Launches a headless Chromium browser with dark-mode preference
2. Navigates to the target URL and waits for `networkidle`
3. Serialises CSS-in-JS rules (emotion, styled-components) from the browser's CSSOM back into `<style>` tags so they survive the DOM snapshot
4. Captures every resource the browser loaded (fonts, images, CSS) via response interception
5. Rewrites all asset paths to relative local paths
6. Strips `<script>` tags (unless `--keep-js`)

### Standard mode

1. Fetches pages with `requests` using a real browser User-Agent
2. Parses HTML and downloads referenced assets recursively
3. Rewrites `url()` references in CSS files

### Both modes

- Ensures all forms have `method="post"` (JS-driven forms often omit this attribute)
- Probes a guaranteed-nonexistent path to capture the real 404 response; if the site redirects 404s to a login page, that redirect is recorded in `config.toml` and `404.html` uses a meta-refresh fallback
- Generates a theme-aware `.posted` file (dark/light) with a failed-login error message
- Generates `thinkst-canary-metadata/config.toml` with `response_code = 200` for pages with POST forms, so the Canary returns 200 after capturing credentials

## Deploying to Canary

1. Review the output folder and tweak assets as needed
2. Zip it: `python canary_webroot_cloner.py ... --zip`
   (or `cd canary_webroot && zip -r ../canary_webroot.zip .`)
3. In the Canary Console: **Configure Canary → HTTP Web Server → Upload custom webroot**
4. Set **HTTP Page Skin** to **User Supplied** and deploy