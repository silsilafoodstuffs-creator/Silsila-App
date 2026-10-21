#!/usr/bin/env python3
"""Enrich existing Silsila ERP catalog records with actual product-pack photos.

Images are downloaded as bytes and written to PostgreSQL bytea (image_data); image_url
is cleared. This script intentionally does NOT publish marketplace products or invent
supplier IDs/prices. Open Food Facts is an opt-in open-data source, not Amazon data.
"""
from __future__ import annotations

import json
import os
import re
import sys
import time
import urllib.error
import urllib.parse
import urllib.request
from typing import Any

BASE_URL = os.environ.get("SUPABASE_URL", "").rstrip("/")
SERVICE_KEY = os.environ.get("SUPABASE_SERVICE_ROLE_KEY", "")
COMPANY_ID = os.environ.get("SILSILA_ERP_COMPANY_ID", "")
OFF_API = "https://world.openfoodfacts.org/cgi/search.pl"
USER_AGENT = "SilsilaCatalogEnricher/1.0 (catalog administrator)"
MIN_BYTES = 12_000
MIN_SIDE = 300
MAX_BYTES = 4 * 1024 * 1024
MAX_ITEMS = int(os.environ.get("SILSILA_IMAGE_IMPORT_LIMIT", "250"))
DRY_RUN = os.environ.get("SILSILA_IMAGE_IMPORT_DRY_RUN", "1") != "0"

# Only match categories that exist in the ERP tree. We don't create fake records.
GROUP_HINTS = {
    "FOOD-GHEE": ["ghee", "سمن"],
    "FOOD-OILS": ["oil", "زيت"],
    "FOOD-PASTA": ["pasta", "noodle", "مكرونة"],
    "FOOD-LEGUMES": ["lentil", "bean", "chickpea", "عدس", "فول", "حمص"],
    "FOOD-HOT-DRINKS": ["tea", "coffee", "شاي", "قهوة"],
    "FOOD-SOFT-DRINKS": ["soda", "water", "cola", "مشروب", "مياه"],
    "FOOD-CHEESE": ["cheese", "جبن"],
    "FOOD-DAIRY": ["milk", "yogurt", "لبن", "زبادي"],
    "FOOD-JUICES": ["juice", "عصير"],
    "FOOD-SNACKS": ["snack", "chips", "crisps", "مقرمشات", "شيبسي"],
    "FOOD-CANNED": ["canned", "معلبات"],
    "FOOD-CHOCOLATE": ["chocolate", "شيكولاتة"],
    "FOOD-CANDY": ["candy", "sweet", "حلوى"],
    "FOOD-FROZEN": ["frozen", "مجمد"],
    "HOME-CLEANING": ["cleaner", "cleaning", "منظف"],
    "HOME-LAUNDRY": ["laundry", "detergent", "غسيل", "مسحوق"],
    "HOME-PAPER": ["tissue", "paper", "مناديل", "ورقيات"],
    "PERSONAL-CARE": ["shampoo", "soap", "personal care", "شامبو", "صابون"],
}


def request_json(url: str) -> dict[str, Any]:
    req = urllib.request.Request(url, headers={"User-Agent": USER_AGENT, "Accept": "application/json"})
    with urllib.request.urlopen(req, timeout=25) as response:
        return json.loads(response.read().decode("utf-8"))


def rest(method: str, table: str, query: str = "", payload: Any = None) -> Any:
    url = f"{BASE_URL}/rest/v1/{table}" + (f"?{query}" if query else "")
    body = None if payload is None else json.dumps(payload, ensure_ascii=False).encode("utf-8")
    headers = {
        "apikey": SERVICE_KEY,
        "Authorization": f"Bearer {SERVICE_KEY}",
        "Accept": "application/json",
        "Content-Type": "application/json",
        "Prefer": "return=representation",
        "User-Agent": USER_AGENT,
    }
    req = urllib.request.Request(url, data=body, headers=headers, method=method)
    with urllib.request.urlopen(req, timeout=45) as response:
        raw = response.read()
        return json.loads(raw.decode("utf-8")) if raw else []


def normalized(value: str) -> str:
    return re.sub(r"[^a-z0-9\u0600-\u06ff]+", " ", value.casefold()).strip()


def download_image(url: str) -> tuple[bytes, str] | None:
    if not url.startswith("https://"):
        return None
    req = urllib.request.Request(url, headers={"User-Agent": USER_AGENT})
    try:
        with urllib.request.urlopen(req, timeout=25) as response:
            data = response.read(MAX_BYTES + 1)
            mime = response.headers.get_content_type().lower()
    except (urllib.error.URLError, TimeoutError):
        return None
    if len(data) < MIN_BYTES or len(data) > MAX_BYTES or mime not in {"image/jpeg", "image/png", "image/webp"}:
        return None
    # Validate common image headers and dimensions without third-party dependencies.
    width, height = image_dimensions(data, mime)
    if not width or not height or min(width, height) < MIN_SIDE:
        return None
    return data, mime


def image_dimensions(data: bytes, mime: str) -> tuple[int, int]:
    try:
        if mime == "image/png" and data[:8] == b"\x89PNG\r\n\x1a\n":
            return int.from_bytes(data[16:20], "big"), int.from_bytes(data[20:24], "big")
        if mime == "image/jpeg" and data[:2] == b"\xff\xd8":
            i = 2
            while i + 9 < len(data):
                if data[i] != 0xFF:
                    i += 1
                    continue
                marker = data[i + 1]
                size = int.from_bytes(data[i + 2:i + 4], "big")
                if marker in (0xC0, 0xC1, 0xC2, 0xC3, 0xC5, 0xC6, 0xC7, 0xC9, 0xCA, 0xCB, 0xCD, 0xCE, 0xCF):
                    return int.from_bytes(data[i + 7:i + 9], "big"), int.from_bytes(data[i + 5:i + 7], "big")
                if size < 2:
                    break
                i += 2 + size
        if mime == "image/webp" and data[:4] == b"RIFF" and data[8:12] == b"WEBP":
            kind = data[12:16]
            if kind == b"VP8X" and len(data) >= 30:
                return 1 + int.from_bytes(data[24:27], "little"), 1 + int.from_bytes(data[27:30], "little")
    except (IndexError, ValueError):
        pass
    return 0, 0


def off_candidates(item: dict[str, Any]) -> list[dict[str, Any]]:
    barcode = str(item.get("barcode") or "").strip()
    name = str(item.get("item_name") or "").strip()
    brand = str(item.get("brand_name") or "").strip()
    searches = [barcode] if barcode else []
    if name:
        searches.append(" ".join(part for part in (brand, name) if part))
        searches.append(name)
    found: list[dict[str, Any]] = []
    seen: set[str] = set()
    for term in searches:
        params = urllib.parse.urlencode({
            "search_terms": term,
            "page_size": "12",
            "json": "1",
            "fields": "code,product_name,product_name_en,brands,image_front_url,image_front_small_url,image_url,countries_tags",
        })
        try:
            data = request_json(f"{OFF_API}?{params}")
        except (urllib.error.URLError, TimeoutError, json.JSONDecodeError):
            continue
        for product in data.get("products", []):
            code = str(product.get("code") or "")
            if code and code not in seen:
                seen.add(code)
                found.append(product)
        time.sleep(4.2)  # public API read limit: at most 15 requests/minute
    return found


def choose_image(item: dict[str, Any], candidates: list[dict[str, Any]]) -> tuple[dict[str, Any], bytes, str] | None:
    barcode = str(item.get("barcode") or "").strip()
    raw_name = str(item.get("item_name") or "")
    raw_brand = str(item.get("brand_name") or "")
    target = normalized(" ".join((raw_brand, raw_name)))
    arabic_terms = {
        "أرز": "rice", "بسمتي": "basmati", "مكرونة": "pasta", "زيت": "cooking oil",
        "سمن": "ghee", "سكر": "sugar", "دقيق": "flour", "عدس": "lentils",
        "فول": "fava beans", "حمص": "chickpeas", "شاي": "tea", "قهوة": "coffee",
        "عصير": "juice", "جبن": "cheese", "لبن": "milk", "زبادي": "yogurt",
        "مياه": "water", "مشروب غازي": "soft drink", "بسكويت": "biscuits",
        "شوكولاتة": "chocolate", "شيكولاتة": "chocolate", "منظف": "cleaner",
        "مسحوق": "laundry detergent", "مناديل": "tissue", "مجمد": "frozen food",
        "تمر": "dates", "عسل": "honey", "مربى": "jam", "كاتشب": "ketchup",
        "مايونيز": "mayonnaise", "بهارات": "spices", "توابل": "seasoning",
        "مكسرات": "nuts", "شيبسي": "potato chips", "رقائق": "chips",
    }
    english_terms = " ".join(english for arabic, english in arabic_terms.items() if arabic in raw_name)
    search_target = normalized(" ".join((target, english_terms)))
    best = None
    best_score = 0.0
    for candidate in candidates:
        code = str(candidate.get("code") or "")
        product_title = normalized(" ".join(str(candidate.get(k) or "") for k in ("product_name", "product_name_en")))
        brands = normalized(str(candidate.get("brands") or ""))
        title = normalized(" ".join((product_title, brands)))
        if barcode and code == barcode:
            score = 1.0
        else:
            a, b = set(search_target.split()), set(title.split())
            score = len(a & b) / max(1, len(a | b))
            brand = normalized(raw_brand)
            if brand and brand in brands:
                score += 0.25
            if not brand and not (set(normalized(english_terms).split()) & set(product_title.split())):
                score = min(score, 0.25)
        threshold = 0.72 if not barcode and not raw_brand else 0.42
        if score < threshold or score <= best_score:
            continue
        image_url = candidate.get("image_front_url") or candidate.get("image_url")
        if not image_url:
            continue
        image = download_image(str(image_url))
        if image:
            best, best_score = (candidate, image[0], image[1]), score
    return best


def main() -> int:
    if not BASE_URL or not SERVICE_KEY or not COMPANY_ID:
        print("Set SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY, and SILSILA_ERP_COMPANY_ID.", file=sys.stderr)
        return 2
    if not DRY_RUN:
        print("LIVE MODE: matching records will be updated in Supabase.")
    else:
        print("DRY RUN: no database changes will be made. Set SILSILA_IMAGE_IMPORT_DRY_RUN=0 to write.")

    groups = rest("GET", "erp_item_groups", urllib.parse.urlencode({
        "company_id": f"eq.{COMPANY_ID}", "select": "id,group_code,group_name,image_data",
    }))
    categories = rest("GET", "categories", urllib.parse.urlencode({
        "select": "id,name,image_data", "is_active": "eq.true", "limit": "500",
    }))
    category_aliases = {
        "FOOD-GHEE": ["سمنات", "سمن"],
        "FOOD-OILS": ["زيوت", "زيت"],
        "FOOD-PASTA": ["مكرونات", "مكرونة ونودلز", "مكرونة"],
        "FOOD-LEGUMES": ["بقوليات", "بقوليات وحبوب"],
        "FOOD-HOT-DRINKS": ["مشروبات ساخنة", "شاي وقهوة وكاكاو"],
        "FOOD-SOFT-DRINKS": ["مشروبات غازية", "مشروبات غازية ومياه"],
        "FOOD-CHEESE": ["جبن"],
        "FOOD-DAIRY": ["ألبان"],
        "FOOD-JUICES": ["عصائر"],
        "FOOD-SNACKS": ["مقرمشات", "مقرمشات وسناكس"],
        "FOOD-CANNED": ["معلبات"],
        "FOOD-CHOCOLATE": ["شيكولاتة"],
        "FOOD-CANDY": ["حلويات"],
        "FOOD-FROZEN": ["مجمدات", "أغذية مجمدة"],
        "HOME-CLEANING": ["منظفات"],
        "HOME-LAUNDRY": ["منظفات"],
        "HOME-PAPER": ["ورقيات"],
        "PERSONAL-CARE": ["عناية شخصية"],
    }
    items = rest("GET", "erp_items", urllib.parse.urlencode({
        "company_id": f"eq.{COMPANY_ID}",
        "select": "id,item_code,item_name,barcode,brand_name,group_id,image_data,image_url",
        "order": "item_name.asc",
        "limit": str(MAX_ITEMS),
    }))
    print(f"ERP groups: {len(groups)}; items checked: {len(items)}")
    group_by_id = {g["id"]: g for g in groups}
    refreshed_groups: set[str] = set()
    updated = 0
    for index, item in enumerate(items, 1):
        # Existing photos smaller than the quality threshold are considered placeholders.
        old = str(item.get("image_data") or "")
        if len(old) > 25_000:
            continue
        candidates = off_candidates(item)
        match = choose_image(item, candidates)
        if not match:
            continue
        product, image_bytes, mime = match
        image_value = "\\x" + image_bytes.hex()
        source_page = "https://world.openfoodfacts.org/product/" + urllib.parse.quote(str(product.get("code") or ""))
        if not DRY_RUN:
            rest("PATCH", "erp_items", urllib.parse.urlencode({"id": f"eq.{item['id']}", "company_id": f"eq.{COMPANY_ID}"}), {
                "image_data": image_value,
                "image_mime_type": mime,
                "image_url": None,
                "source_name": "Open Food Facts",
                "source_url": source_page,
            })
        updated += 1
        print(f"[{index}/{len(items)}] {item.get('item_name')} <- {product.get('product_name') or product.get('product_name_en')} ({len(image_bytes)} bytes){' [dry-run]' if DRY_RUN else ''}")
        group_id = item.get("group_id")
        if group_id and group_id not in refreshed_groups:
            refreshed_groups.add(group_id)
            group = group_by_id.get(group_id)
            if group and (len(str(group.get("image_data") or "")) <= 25_000):
                if not DRY_RUN:
                    rest("PATCH", "erp_item_groups", urllib.parse.urlencode({"id": f"eq.{group_id}", "company_id": f"eq.{COMPANY_ID}"}), {
                        "image_data": image_value, "image_mime_type": mime, "image_url": None,
                    })
                # Use a real pack shot as a representative category photo only
                # where the category name maps explicitly to this ERP group.
                aliases = category_aliases.get(str(group.get("group_code") or ""), [])
                normalized_aliases = {normalized(alias) for alias in aliases}
                for category in categories:
                    if normalized(str(category.get("name") or "")) not in normalized_aliases:
                        continue
                    if len(str(category.get("image_data") or "")) > 25_000:
                        continue
                    if not DRY_RUN:
                        rest("PATCH", "categories", urllib.parse.urlencode({"id": f"eq.{category['id']}"}), {
                            "image_data": image_value, "image_mime_type": mime, "image_url": None,
                        })
                    print(f"  category photo: {category.get('name')}{' [dry-run]' if DRY_RUN else ''}")
        time.sleep(0.2)
    print(f"Image candidates accepted: {updated}; writes performed: {0 if DRY_RUN else updated}.")
    print("No match means no change. Review source licensing and product identity before enabling these images in customer-facing listings.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
