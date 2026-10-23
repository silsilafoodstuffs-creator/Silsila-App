#!/usr/bin/env python3
"""Download governorate emblems/flags and store normalized PNG bytes in Supabase bytea."""
from __future__ import annotations

import hashlib
import io
import json
import os
import sys
import time
from urllib.error import HTTPError, URLError
from urllib.parse import urlencode, urlsplit, urlunsplit, parse_qsl, unquote
from urllib.request import Request, urlopen
from datetime import datetime, timezone

import cairosvg
from PIL import Image

SUPABASE_URL = os.environ.get("SUPABASE_URL", "https://teitsopmhruczplwlwgn.supabase.co").rstrip("/")
SERVICE_KEY = os.environ.get("SUPABASE_SERVICE_ROLE_KEY", "")
COMPANY_ID = os.environ.get("SILSILA_COMPANY_ID", "47278c99-7743-4dd4-9ce6-d11f28e02504")
MAX_DOWNLOAD_BYTES = 8 * 1024 * 1024
USER_AGENT = "SilsilaERP-GeographicAssets/1.0 (contact: silsila.foodstuffs@gmail.com)"


def request_bytes(url: str) -> tuple[bytes, str]:
    # Ask Wikimedia for a thumbnail instead of repeatedly downloading full-resolution originals.
    parts = urlsplit(url)
    if "commons.wikimedia.org" in parts.netloc and "/wiki/Special:FilePath/" in parts.path:
        query = dict(parse_qsl(parts.query, keep_blank_values=True))
        query["width"] = "256"
        url = urlunsplit((parts.scheme, parts.netloc, parts.path, urlencode(query), parts.fragment))

    headers = {
        "User-Agent": USER_AGENT,
        "Accept": "image/png,image/jpeg,image/gif,image/svg+xml,*/*;q=0.8",
    }
    for attempt in range(6):
        req = Request(url, headers=headers)
        try:
            with urlopen(req, timeout=45) as response:
                data = response.read(MAX_DOWNLOAD_BYTES + 1)
                content_type = response.headers.get_content_type().lower()
            if not data or len(data) > MAX_DOWNLOAD_BYTES:
                raise ValueError(f"Image is empty or exceeds {MAX_DOWNLOAD_BYTES} bytes")
            if content_type in ("text/html", "application/xhtml+xml") or data.lstrip().lower().startswith((b"<!doctype html", b"<html")):
                raise ValueError("The source returned HTML instead of an image")
            return data, content_type
        except HTTPError as exc:
            if exc.code not in (429, 500, 502, 503, 504) or attempt == 5:
                raise
            retry_after = exc.headers.get("Retry-After")
            try:
                delay = max(2.0, min(float(retry_after), 60.0)) if retry_after else min(2 ** (attempt + 1), 30)
            except ValueError:
                delay = min(2 ** (attempt + 1), 30)
            print(f"HTTP {exc.code}; waiting {delay:.0f}s before retry {attempt + 1}/5", file=sys.stderr)
            time.sleep(delay)
    raise RuntimeError("Image download retry loop ended unexpectedly")


def normalize_png(data: bytes, content_type: str) -> bytes:
    looks_svg = content_type == "image/svg+xml" or b"<svg" in data[:2048].lower()
    if looks_svg:
        data = cairosvg.svg2png(bytestring=data, output_width=256)
    with Image.open(io.BytesIO(data)) as image:
        image.load()
        image = image.convert("RGBA")
        image.thumbnail((256, 256), Image.Resampling.LANCZOS)
        out = io.BytesIO()
        image.save(out, format="PNG", optimize=True)
        return out.getvalue()


def api_headers() -> dict[str, str]:
    return {
        "apikey": SERVICE_KEY,
        "Authorization": f"Bearer {SERVICE_KEY}",
        "Content-Type": "application/json",
        "Accept": "application/json",
        "Prefer": "return=minimal",
        "User-Agent": USER_AGENT,
    }


def api_get_governorates() -> list[dict]:
    query = urlencode({
        "select": "geo_code,name_ar,logo_url,logo_source_url,logo_sha256",
        "company_id": f"eq.{COMPANY_ID}",
        "level": "eq.governorate",
        "order": "geo_code.asc",
    })
    req = Request(f"{SUPABASE_URL}/rest/v1/erp_geographic_data?{query}", headers=api_headers())
    with urlopen(req, timeout=45) as response:
        result = json.loads(response.read().decode("utf-8"))
    if not isinstance(result, list):
        raise RuntimeError("Supabase did not return a governorate array")
    return result


def resolve_thumbnail_urls(rows: list[dict]) -> dict[str, str]:
    """Resolve many Commons file titles in one API request, then download from upload.wikimedia.org CDN."""
    titles_by_code: dict[str, str] = {}
    for row in rows:
        code = row.get("geo_code")
        source_url = row.get("logo_source_url") or ""
        parts = urlsplit(source_url)
        if code and "commons.wikimedia.org" in parts.netloc and "/wiki/File:" in parts.path:
            title = unquote(parts.path.split("/wiki/", 1)[1]).replace("_", " ")
            titles_by_code[code] = title

    if not titles_by_code:
        return {}

    params = urlencode({
        "action": "query",
        "titles": "|".join(titles_by_code.values()),
        "prop": "imageinfo",
        "iiprop": "url",
        "iiurlwidth": "256",
        "format": "json",
    })
    endpoint = "https://commons.wikimedia.org/w/api.php?" + params
    payload = None
    for attempt in range(5):
        req = Request(endpoint, headers={"User-Agent": USER_AGENT, "Accept": "application/json"})
        try:
            with urlopen(req, timeout=45) as response:
                payload = json.loads(response.read().decode("utf-8"))
            break
        except HTTPError as exc:
            if exc.code not in (429, 500, 502, 503, 504) or attempt == 4:
                raise
            delay = min(10 * (attempt + 1), 60)
            print(f"Commons API HTTP {exc.code}; waiting {delay}s before retry {attempt + 1}/4", file=sys.stderr)
            time.sleep(delay)
    if payload is None:
        raise RuntimeError("Commons API returned no payload")

    title_to_code = {title.casefold(): code for code, title in titles_by_code.items()}
    resolved: dict[str, str] = {}
    for page in payload.get("query", {}).get("pages", {}).values():
        title = str(page.get("title", "")).replace("_", " ").casefold()
        code = title_to_code.get(title)
        imageinfo = page.get("imageinfo") or []
        if code and imageinfo:
            resolved[code] = imageinfo[0].get("thumburl") or imageinfo[0].get("url")
    return resolved


def patch_row(geo_code: str, png: bytes, sha: str) -> None:
    query = urlencode({
        "company_id": f"eq.{COMPANY_ID}",
        "geo_code": f"eq.{geo_code}",
        "level": "eq.governorate",
    })
    payload = {
        # PostgreSQL bytea hex input representation, passed as JSON string.
        "logo_bytes": "\\x" + png.hex(),
        "logo_mime_type": "image/png",
        "logo_sha256": sha,
        "logo_bytes_updated_at": datetime.now(timezone.utc).isoformat(),
    }
    req = Request(
        f"{SUPABASE_URL}/rest/v1/erp_geographic_data?{query}",
        data=json.dumps(payload, ensure_ascii=False).encode("utf-8"),
        headers={**api_headers(), "Content-Type": "application/json"},
        method="PATCH",
    )
    with urlopen(req, timeout=60) as response:
        if response.status not in (200, 204):
            raise RuntimeError(f"Supabase update returned HTTP {response.status}")


def main() -> int:
    if not SERVICE_KEY:
        print("ERROR: SUPABASE_SERVICE_ROLE_KEY secret is required.", file=sys.stderr)
        return 2

    rows = api_get_governorates()
    if len(rows) != 27:
        print(f"ERROR: expected 27 governorates, received {len(rows)}.", file=sys.stderr)
        return 2

    failures: list[tuple[str, str]] = []
    saved = 0
    skipped = 0
    pending_rows = [row for row in rows if not row.get("logo_sha256")]
    try:
        resolved_urls = resolve_thumbnail_urls(pending_rows)
        print(f"Resolved {len(resolved_urls)}/{len(pending_rows)} Commons thumbnails in one API request")
    except (HTTPError, URLError, OSError, ValueError, RuntimeError) as exc:
        print(f"WARNING: Commons thumbnail API unavailable; falling back to stored file URLs: {exc}", file=sys.stderr)
        resolved_urls = {}

    for row in rows:
        code = row.get("geo_code") or "(missing-code)"
        name = row.get("name_ar") or code
        url = resolved_urls.get(code) or row.get("logo_url") or row.get("logo_source_url")
        if row.get("logo_sha256"):
            print(f"SKIP {code} {name}: image bytes are already stored")
            skipped += 1
            continue
        if not url:
            failures.append((code, f"{name}: missing logo_url"))
            continue
        try:
            original, content_type = request_bytes(url)
            png = normalize_png(original, content_type)
            sha = hashlib.sha256(png).hexdigest()
            if row.get("logo_sha256") == sha:
                print(f"SKIP {code} {name}: stored image hash is current")
                skipped += 1
                continue
            patch_row(code, png, sha)
            print(f"SAVED {code} {name}: {len(png)} bytes PNG sha256={sha}")
            saved += 1
            time.sleep(5.0)
        except (HTTPError, URLError, OSError, ValueError, RuntimeError) as exc:
            failures.append((code, f"{name}: {type(exc).__name__}: {exc}"))
            print(f"FAILED {code} {name}: {type(exc).__name__}: {exc}", file=sys.stderr)

    print(f"SUMMARY total={len(rows)} saved={saved} unchanged={skipped} failed={len(failures)}")
    if failures:
        for code, detail in failures:
            print(f"UNRESOLVED {code}: {detail}", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
