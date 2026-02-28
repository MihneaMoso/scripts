"""
Recursive website downloader — similar to:
  wget --recursive -l 2 --no-clobber --page-requisites \
       --convert-links --restrict-file-names=windows \
       --domains=example.com --no-parent <url>

Features:
  - Recursively follows same-domain links up to a configurable depth.
  - Downloads page requisites (CSS, JS, images, fonts, etc.) regardless
    of which (sub)domain they live on, so pages render correctly offline.
  - Rewrites every URL reference in saved HTML/CSS to point at the local
    copy, so the mirror works when opened from disk.
  - Windows-safe filenames (no special chars, adds .html extension).
"""

import re
import os
import sys
import time
import random
import hashlib
from collections import deque
from urllib.parse import urljoin, urlparse, urlunparse, unquote

import requests
from requests.adapters import HTTPAdapter
from urllib3.util.retry import Retry
from bs4 import BeautifulSoup

# ---------------------------------------------------------------------------
# Configuration
# ---------------------------------------------------------------------------
START_URL = "https://example.com/"
OUTPUT_DIR = "output"
MAX_DEPTH = 2                       # link-follow depth (0 = start page only)
ALLOWED_DOMAINS = {"example.com"}  # only follow links on these domains
REQUEST_TIMEOUT = 30                # seconds
REQUEST_DELAY = (0.5, 1.5)         # random delay range (seconds) between requests
USER_AGENTS = [
    "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36",
    "Mozilla/5.0 (Windows NT 10.0; Win64; x64; rv:121.0) Gecko/20100101 Firefox/121.0",
    "Mozilla/5.0 (Macintosh; Intel Mac OS X 14_2) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.2 Safari/605.1.15",
    "Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36",
    "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/119.0.0.0 Safari/537.36 Edg/119.0.0.0",
]

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

def _sanitise_path_component(component: str) -> str:
    """Make a single path component safe for Windows filesystems."""
    # Replace characters illegal on Windows
    component = re.sub(r'[<>:"|?*]', '_', component)
    # Collapse runs of whitespace / dots that would be problematic
    component = component.strip(". ")
    return component or "_"


def url_to_local_path(url: str) -> str:
    """
    Convert a URL into a safe local filepath under OUTPUT_DIR.

    - Strips the scheme.
    - Keeps the netloc (domain) as the first directory so assets from
      different domains don't collide.
    - Adds .html for text/html resources without an extension.
    - Query strings / fragments are hashed into the filename to keep
      distinct pages separate.
    """
    parsed = urlparse(url)
    netloc = _sanitise_path_component(parsed.netloc or "unknown")
    raw_path = unquote(parsed.path).strip("/")

    # Build a list of sanitised path parts
    parts = [_sanitise_path_component(p) for p in raw_path.split("/") if p]
    if not parts:
        parts = ["index.html"]

    # Append a hash of query/fragment if present to differentiate pages
    extra = parsed.query + parsed.fragment
    if extra:
        suffix = hashlib.md5(extra.encode()).hexdigest()[:10]
        base, ext = os.path.splitext(parts[-1])
        parts[-1] = f"{base}_{suffix}{ext}"

    return os.path.join(OUTPUT_DIR, netloc, *parts)


def _ensure_html_extension(path: str) -> str:
    """If the file has no extension, append .html."""
    _, ext = os.path.splitext(path)
    if not ext:
        path += ".html"
    return path


def _is_same_domain(url: str) -> bool:
    """Check whether a URL belongs to one of the ALLOWED_DOMAINS."""
    netloc = urlparse(url).netloc.lower()
    return any(netloc == d or netloc.endswith("." + d) for d in ALLOWED_DOMAINS)


def _normalise_url(url: str) -> str:
    """Strip fragment and trailing slash for de-duplication."""
    p = urlparse(url)
    path = p.path.rstrip("/") or "/"
    return urlunparse((p.scheme, p.netloc, path, p.params, p.query, ""))


def _relative_link(from_path: str, to_path: str) -> str:
    """Return a relative path from *from_path* to *to_path*."""
    return os.path.relpath(to_path, os.path.dirname(from_path)).replace("\\", "/")


# ---------------------------------------------------------------------------
# Downloader class
# ---------------------------------------------------------------------------

class SiteMirror:
    def __init__(self):
        self.session = requests.Session()

        # Automatic retry with exponential backoff on 429 / 500 / 502 / 503
        retry_strategy = Retry(
            total=5,                        # up to 5 retries per request
            backoff_factor=1,               # waits 1s, 2s, 4s, 8s, 16s …
            status_forcelist=[429, 500, 502, 503, 504],
            respect_retry_after_header=True, # honour Retry-After from server
            allowed_methods=["GET", "HEAD"],
        )
        adapter = HTTPAdapter(max_retries=retry_strategy)
        self.session.mount("https://", adapter)
        self.session.mount("http://", adapter)

        # url  -> local file path   (for everything we saved)
        self.saved: dict[str, str] = {}
        # BFS queue: (url, depth)
        self.queue: deque[tuple[str, int]] = deque()
        # Set of normalised URLs already enqueued (pages only)
        self.enqueued: set[str] = set()

    # ----- throttled request ------------------------------------------------

    def _get(self, url: str, **kwargs) -> requests.Response:
        """GET with a polite random delay and rotating User-Agent."""
        time.sleep(random.uniform(*REQUEST_DELAY))
        self.session.headers["User-Agent"] = random.choice(USER_AGENTS)
        return self.session.get(url, timeout=REQUEST_TIMEOUT, **kwargs)

    # ----- asset downloading ------------------------------------------------

    def _download_binary(self, url: str) -> str | None:
        """Download a binary asset and return its local path, or None."""
        norm = _normalise_url(url)
        if norm in self.saved:
            return self.saved[norm]
        try:
            resp = self._get(url)
            resp.raise_for_status()
        except Exception as exc:
            print(f"  [!] asset error {url}: {exc}")
            return None
        local = url_to_local_path(url)
        os.makedirs(os.path.dirname(local), exist_ok=True)
        with open(local, "wb") as fh:
            fh.write(resp.content)
        self.saved[norm] = local
        print(f"  [asset] {url}  ->  {local}")
        return local

    # ----- CSS url() rewriting ---------------------------------------------

    _CSS_URL_RE = re.compile(
        r"""url\(\s*(['"]?)(.+?)\1\s*\)""", re.IGNORECASE
    )

    def _download_and_rewrite_css(self, css_url: str) -> str | None:
        """Download a CSS file, rewrite url() references, save locally."""
        norm = _normalise_url(css_url)
        if norm in self.saved:
            return self.saved[norm]
        try:
            resp = self._get(css_url)
            resp.raise_for_status()
        except Exception as exc:
            print(f"  [!] CSS error {css_url}: {exc}")
            return None

        css_local = url_to_local_path(css_url)
        os.makedirs(os.path.dirname(css_local), exist_ok=True)

        text = resp.text

        def _replace_css_url(m):
            quote = m.group(1)
            ref = m.group(2).strip()
            if ref.startswith("data:"):
                return m.group(0)
            abs_url = urljoin(css_url, ref)
            asset_path = self._download_binary(abs_url)
            if asset_path:
                rel = _relative_link(css_local, asset_path)
                return f"url({quote}{rel}{quote})"
            return m.group(0)

        text = self._CSS_URL_RE.sub(_replace_css_url, text)
        with open(css_local, "w", encoding="utf-8") as fh:
            fh.write(text)
        self.saved[norm] = css_local
        print(f"  [css]   {css_url}  ->  {css_local}")
        return css_local

    # ----- single page processing -------------------------------------------

    # Tags & attributes that reference external resources
    _ASSET_ATTRS = [
        ("img",    "src"),
        ("img",    "data-src"),      # lazy-loaded images
        ("script", "src"),
        ("link",   "href"),          # CSS, icons, preload…
        ("source", "src"),
        ("source", "srcset"),
        ("video",  "src"),
        ("video",  "poster"),
        ("audio",  "src"),
    ]

    def _process_page(self, url: str, depth: int):
        """Download an HTML page, its requisites, and enqueue child links."""
        norm = _normalise_url(url)
        if norm in self.saved:
            return
        try:
            resp = self._get(url)
            resp.raise_for_status()
        except Exception as exc:
            print(f"[!] page error {url}: {exc}")
            return

        content_type = resp.headers.get("Content-Type", "")
        if "text/html" not in content_type:
            # Not an HTML page — save as binary asset instead
            local = url_to_local_path(url)
            os.makedirs(os.path.dirname(local), exist_ok=True)
            with open(local, "wb") as fh:
                fh.write(resp.content)
            self.saved[norm] = local
            return

        soup = BeautifulSoup(resp.text, "html.parser")
        page_local = _ensure_html_extension(url_to_local_path(url))

        # --- 1. Download page requisites (assets) --------------------------
        for tag_name, attr in self._ASSET_ATTRS:
            for tag in soup.find_all(tag_name):
                raw = tag.get(attr)
                if not raw:
                    continue

                # Handle srcset (comma-separated list of "url size")
                if attr == "srcset":
                    new_parts = []
                    for part in raw.split(","):
                        tokens = part.strip().split()
                        if not tokens:
                            continue
                        asset_url = urljoin(url, tokens[0])
                        local = self._download_binary(asset_url)
                        if local:
                            tokens[0] = _relative_link(page_local, local)
                        new_parts.append(" ".join(tokens))
                    tag[attr] = ", ".join(new_parts)
                    continue

                asset_url = urljoin(url, raw)

                # CSS gets special treatment so we can rewrite url() inside it
                is_css = (
                    tag_name == "link"
                    and (tag.get("rel") or [""])[0] == "stylesheet"
                )
                if is_css:
                    local = self._download_and_rewrite_css(asset_url)
                else:
                    local = self._download_binary(asset_url)

                if local:
                    tag[attr] = _relative_link(page_local, local)

        # Inline <style> blocks — rewrite url() references
        for style_tag in soup.find_all("style"):
            if style_tag.string:
                def _replace_inline(m, _base=url, _page=page_local):
                    quote = m.group(1)
                    ref = m.group(2).strip()
                    if ref.startswith("data:"):
                        return m.group(0)
                    abs_url = urljoin(_base, ref)
                    asset_path = self._download_binary(abs_url)
                    if asset_path:
                        rel = _relative_link(_page, asset_path)
                        return f"url({quote}{rel}{quote})"
                    return m.group(0)
                style_tag.string = self._CSS_URL_RE.sub(
                    _replace_inline, style_tag.string
                )

        # --- 2. Discover and enqueue child links ---------------------------
        if depth < MAX_DEPTH:
            for a_tag in soup.find_all("a", href=True):
                href = a_tag["href"]
                child_url = _normalise_url(urljoin(url, href))
                if _is_same_domain(child_url) and child_url not in self.enqueued:
                    self.enqueued.add(child_url)
                    self.queue.append((child_url, depth + 1))

        # --- 3. Rewrite <a href> to local paths (for already-saved pages) --
        #     We do a second pass at the end (see _rewrite_links) so that
        #     links to pages we haven't downloaded yet can also be converted.

        # --- 4. Save the page -----------------------------------------------
        os.makedirs(os.path.dirname(page_local), exist_ok=True)
        with open(page_local, "w", encoding="utf-8") as fh:
            fh.write(str(soup))
        self.saved[norm] = page_local
        print(f"[page]  {url}  ->  {page_local}  (depth={depth})")

    # ----- second pass: convert <a> links -----------------------------------

    def _rewrite_links(self):
        """
        After all pages are downloaded, open each saved HTML file and
        rewrite every <a href="…"> that points at another saved page
        so it uses a relative local path.
        """
        print("\n— Rewriting links …")
        for norm_url, local_path in list(self.saved.items()):
            if not local_path.endswith(".html"):
                continue
            with open(local_path, "r", encoding="utf-8") as fh:
                soup = BeautifulSoup(fh.read(), "html.parser")

            changed = False
            for a_tag in soup.find_all("a", href=True):
                href = a_tag["href"]
                abs_url = _normalise_url(urljoin(norm_url, href))
                target_local = self.saved.get(abs_url)
                if target_local:
                    rel = _relative_link(local_path, target_local)
                    if a_tag["href"] != rel:
                        a_tag["href"] = rel
                        changed = True

            if changed:
                with open(local_path, "w", encoding="utf-8") as fh:
                    fh.write(str(soup))
                print(f"  [relink] {local_path}")

    # ----- public entry point -----------------------------------------------

    def run(self, start_url: str):
        norm = _normalise_url(start_url)
        self.enqueued.add(norm)
        self.queue.append((start_url, 0))

        while self.queue:
            url, depth = self.queue.popleft()
            self._process_page(url, depth)

        self._rewrite_links()
        print(f"\nDone – saved {len(self.saved)} files to '{OUTPUT_DIR}/'.")


# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------
if __name__ == "__main__":
    url = sys.argv[1] if len(sys.argv) > 1 else START_URL
    mirror = SiteMirror()
    mirror.run(url)