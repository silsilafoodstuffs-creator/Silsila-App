#!/usr/bin/env python3
"""Import real, reusable category photographs from Wikimedia Commons into Supabase bytea."""
from __future__ import annotations
import html
import os
import re
import sys
import time
from typing import Any

import requests

SUPABASE_URL = os.environ["SUPABASE_URL"].rstrip("/")
SERVICE_KEY = os.environ["SUPABASE_SERVICE_ROLE_KEY"]
COMPANY_ID = os.environ.get("SILSILA_ERP_COMPANY_ID", "47278c99-7743-4dd4-9ce6-d11f28e02504")
API = "https://commons.wikimedia.org/w/api.php"
HEADERS = {
    "User-Agent": "SilsilaERP/1.0 (category photo catalog; source and license attribution recorded)",
}
SESSION = requests.Session()
SESSION.headers.update(HEADERS)
RASTER = {"image/jpeg", "image/png", "image/webp", "image/gif"}


def detect_mime(data: bytes) -> str | None:
    if data.startswith(b"\x89PNG\r\n\x1a\n"):
        return "image/png"
    if data.startswith(b"\xff\xd8\xff"):
        return "image/jpeg"
    if len(data) >= 12 and data[:4] == b"RIFF" and data[8:12] == b"WEBP":
        return "image/webp"
    if data.startswith((b"GIF87a", b"GIF89a")):
        return "image/gif"
    return None


def plain(value: Any, limit: int = 400) -> str:
    value = re.sub(r"<[^>]*>", " ", str(value or ""))
    return re.sub(r"\s+", " ", html.unescape(value)).strip()[:limit]


def get_category_rows() -> list[dict[str, Any]]:
    rows: list[dict[str, Any]] = []
    offset = 0
    while True:
        response = SESSION.get(
            f"{SUPABASE_URL}/rest/v1/erp_item_categories",
            params={
                "select": "id,company_id,activity_code,category_code,category_name,category_name_en,image_mime_type",
                "company_id": f"eq.{COMPANY_ID}",
                "order": "activity_code.asc,category_code.asc",
                "limit": 500,
                "offset": offset,
            },
            headers={"apikey": SERVICE_KEY, "Authorization": f"Bearer {SERVICE_KEY}"},
            timeout=30,
        )
        response.raise_for_status()
        page = response.json()
        rows.extend(page)
        if len(page) < 500:
            break
        offset += len(page)
    return rows


def commons_match(query: str) -> dict[str, Any] | None:
    params = {
        "action": "query", "generator": "search",
        "gsrsearch": f"{query} filetype:bitmap", "gsrnamespace": 6,
        "gsrlimit": 10, "prop": "imageinfo",
        "iiprop": "url|mime|size|extmetadata", "iiurlwidth": 640,
        "format": "json",
    }
    response = SESSION.get(API, params=params, timeout=25)
    response.raise_for_status()
    pages = response.json().get("query", {}).get("pages", {})
    if isinstance(pages, dict):
        pages = list(pages.values())
    for page in pages:
        infos = page.get("imageinfo") or []
        if not infos:
            continue
        info = infos[0]
        if info.get("mime") not in RASTER:
            continue
        if int(info.get("size") or 0) < 10000:
            continue
        image_url = info.get("thumburl") or info.get("url")
        if not image_url or not image_url.startswith("https://"):
            continue
        try:
            image_response = SESSION.get(image_url, timeout=30, stream=True)
            image_response.raise_for_status()
            data = bytearray()
            for chunk in image_response.iter_content(64 * 1024):
                data.extend(chunk)
                if len(data) > 5 * 1024 * 1024:
                    break
            image_response.close()
            if len(data) < 10000 or len(data) > 5 * 1024 * 1024:
                continue
            mime = detect_mime(bytes(data))
            if mime not in RASTER:
                continue
            metadata = info.get("extmetadata") or {}
            license_name = plain((metadata.get("LicenseShortName") or {}).get("value"), 100) or "Wikimedia Commons"
            artist = plain((metadata.get("Artist") or metadata.get("Credit") or {}).get("value"), 250) or "Wikimedia Commons contributor"
            license_url = plain((metadata.get("LicenseUrl") or {}).get("value"), 300) or "https://commons.wikimedia.org/"
            return {
                "data": bytes(data), "mime": mime,
                "source": info.get("descriptionurl") or image_url,
                "attribution": f"{artist} — {license_name} ({license_url})",
            }
        except requests.RequestException as exc:
            print(f"  image download retry candidate: {exc}", flush=True)
    return None


def save_image(row: dict[str, Any], match: dict[str, Any]) -> None:
    url = f"{SUPABASE_URL}/rest/v1/erp_item_categories"
    params = {"id": f"eq.{row['id']}", "company_id": f"eq.{COMPANY_ID}"}
    headers = {
        "apikey": SERVICE_KEY, "Authorization": f"Bearer {SERVICE_KEY}",
        "Content-Type": "application/json", "Prefer": "return=minimal",
    }
    payload = {
        "image_data": "\\x" + match["data"].hex(),
        "image_mime_type": match["mime"],
        "image_url": None,
        "image_source_url": match["source"],
        "image_attribution": match["attribution"],
    }
    response = SESSION.patch(url, params=params, headers=headers, json=payload, timeout=45)
    response.raise_for_status()


def main() -> int:
    if not SERVICE_KEY:
        print("::error::SUPABASE_SERVICE_ROLE_KEY is missing.")
        return 2
    rows = get_category_rows()
    print(f"Loaded {len(rows)} category rows for company {COMPANY_ID}.", flush=True)
    imported = already_real = not_found = errors = 0
    for index, row in enumerate(rows, 1):
        mime = str(row.get("image_mime_type") or "")
        if mime in RASTER:
            already_real += 1
            continue
        code = str(row.get("category_code") or "")
        query = str(row.get("category_name_en") or row.get("category_name") or "").strip()
        if not query:
            not_found += 1
            print(f"[{index}/{len(rows)}] {code}: no category name; skipped", flush=True)
            continue
        try:
            match = commons_match(query)
            if not match:
                not_found += 1
                print(f"[{index}/{len(rows)}] {code} {query}: no suitable raster photo found", flush=True)
            else:
                save_image(row, match)
                imported += 1
                print(f"[{index}/{len(rows)}] IMPORTED {code} {query} [{match['mime']}] — {match['source']}", flush=True)
        except Exception as exc:
            errors += 1
            print(f"::warning::[{index}/{len(rows)}] {code} {query}: {exc}", flush=True)
        time.sleep(0.25)
    print(f"SUMMARY total={len(rows)} imported={imported} already_real={already_real} not_found={not_found} errors={errors}", flush=True)
    # No image match is a reportable outcome, not a workflow failure. Actual API/auth
    # failures are counted per row so a few bad source pages don't discard successful work.
    return 0


if __name__ == "__main__":
    sys.exit(main())
