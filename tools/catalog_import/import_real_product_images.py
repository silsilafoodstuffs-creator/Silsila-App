#!/usr/bin/env python3
"""Enrich existing Silsila ERP catalog records with actual product-pack photos.

Continue validation in a 25-item food-first batch; only exact variant matches may be accepted.

Images are downloaded as bytes and written to PostgreSQL bytea (image_data); image_url
is cleared. This script intentionally does NOT publish marketplace products or invent
supplier IDs/prices. Open Food Facts is an opt-in open-data source, not Amazon data.
"""
from __future__ import annotations

import hashlib
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
# Full-text endpoint; the legacy CGI search is known to return widespread 503s.
OFF_API = "https://search.openfoodfacts.org/search"
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
    # Public data APIs can temporarily return 429/5xx. Retry a small number of
    # times with backoff so transient outages do not immediately discard a query.
    retryable = {429, 500, 502, 503, 504}
    for attempt in range(4):
        req = urllib.request.Request(
            url,
            headers={"User-Agent": USER_AGENT, "Accept": "application/json"},
        )
        try:
            with urllib.request.urlopen(req, timeout=25) as response:
                return json.loads(response.read().decode("utf-8"))
        except urllib.error.HTTPError as exc:
            if exc.code not in retryable or attempt == 3:
                raise
            retry_after = exc.headers.get("Retry-After", "")
            try:
                delay = min(60, max(5, int(retry_after))) if retry_after else 8 * (attempt + 1)
            except ValueError:
                delay = 8 * (attempt + 1)
            print(f"  SOURCE retry {attempt + 1}/3 after HTTP {exc.code}; waiting {delay}s")
            time.sleep(delay)
        except (urllib.error.URLError, TimeoutError):
            if attempt == 3:
                raise
            delay = 8 * (attempt + 1)
            print(f"  SOURCE retry {attempt + 1}/3 after connection failure; waiting {delay}s")
            time.sleep(delay)
    raise RuntimeError("Source request exhausted retries")


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
    # Normalize common Arabic letter variants so source names like "ارز" and
    # ERP names like "أرز" compare consistently.
    value = value.casefold().translate(str.maketrans({
        "أ": "ا", "إ": "ا", "آ": "ا", "ٱ": "ا", "ى": "ي", "ة": None,
    }))
    value = re.sub(r"[\u064b-\u065f\u0670]", "", value)
    return re.sub(r"[^a-z0-9\u0600-\u06ff]+", " ", value).strip()


ARABIC_SEARCH_TERMS = {
    "أرز أبيض مصري": "egyptian white rice",
    "أرز مصري عريض": "egyptian short grain rice",
    "أرز بسمتي": "basmati rice",
    "تمر جاف": "dried dates",
    "تمر معبأ": "packaged dates",
    "توست حبوب كاملة": "wholegrain toast",
    "توست أبيض": "white toast",
    "توفي كراميل": "caramel toffee",
    "تونة قطع": "tuna chunks",
    "جبنة مطبوخة مثلثات": "processed triangle cheese",
    "جبنة شيدر شرائح": "sliced cheddar cheese",
    "جبنة رومي": "romi cheese",
    "جبنة قابلة للدهن": "spreadable cheese",
    "جبنة موتزاريلا": "mozzarella cheese",
    "جبنة فيتا": "feta cheese",
    "جوز هند مبشور": "desiccated coconut",
    "جيلاتين حلويات": "dessert gelatin",
    "حبوب إفطار بالشوكولاتة": "chocolate breakfast cereal",
    "حلاوة طحينية": "tahini halva",
    "حلوى جيلي": "jelly candy",
    "حمص جاف": "dried chickpeas",
    "خضار مشكل مجمد": "frozen mixed vegetables",
    "خل تفاح": "apple cider vinegar",
    "خل أبيض": "white vinegar",
    "بسكويت سادة": "plain biscuits",
    "بسكويت مالح": "salted biscuits",
    "بسلة مجمدة": "frozen peas",
    "بسلة معلبة": "canned peas",
    "بطاطس نصف مقلية مجمدة": "frozen french fries",
    "بطاطس نصف مقلية": "french fries",
    "بقسماط مطحون": "breadcrumbs",
    "ذرة فشار": "popcorn",
    "عصير جهينه": "juhayna juice",
    "عصير بيتي": "betty juice",
    "أرز": "rice",
    "بسمتي": "basmati rice",
    "مكرونة": "pasta",
    "زيت": "cooking oil",
    "سمن": "ghee",
    "سكر": "sugar",
    "دقيق": "flour",
    "عدس": "lentils",
    "فول": "fava beans",
    "حمص": "chickpeas",
    "فاصوليا": "white beans",
    "لوبيا": "black-eyed peas",
    "ترمس": "lupini beans",
    "بسلة": "peas",
    "مجمدة": "frozen",
    "معلبة": "canned",
    "بطاطس": "potato",
    "فشار": "popcorn",
    "ذرة": "corn",
    "شوفان": "oats",
    "برغل": "bulgur",
    "بقسماط": "breadcrumbs",
    "مطحون": "ground",
    "سادة": "plain",
    "مالح": "salted",
    "شاي": "tea",
    "قهوة": "coffee",
    "عصير": "juice",
    "جهينه": "juhayna",
    "بيتي": "betty",
    "مانجا": "mango",
    "كوكتيل": "cocktail",
    "جوافة": "guava",
    "برتقال": "orange",
    "أناناس": "pineapple",
    "تفاح": "apple",
    "جبن": "cheese",
    "لبن": "milk",
    "زبادي": "yogurt",
    "مياه": "water",
    "مشروب غازي": "soft drink",
    "بسكويت": "biscuits",
    "شوكولاتة": "chocolate",
    "شيكولاتة": "chocolate",
    "منظف": "cleaner",
    "مسحوق": "laundry detergent",
    "مناديل": "tissue",
    "مجمد": "frozen food",
    "تمر": "dates",
    "عسل": "honey",
    "مربى": "jam",
    "كاتشب": "ketchup",
    "مايونيز": "mayonnaise",
    "بهارات مشكلة": "mixed spices",
    "بهارات": "spices",
    "توابل": "seasoning",
    "مكسرات": "nuts",
    "شيبسي": "potato chips",
    "رقائق": "chips",
}


def english_terms_for_name(name: str) -> str:
    matches = [(arabic, english) for arabic, english in ARABIC_SEARCH_TERMS.items() if arabic in name]
    # Prefer the most specific phrase, avoiding conflicting requirements such
    # as "potato + french fries" or "rice + white + Egyptian" being assembled
    # from overlapping fragments when a complete phrase exists.
    selected: list[tuple[str, str]] = []
    for arabic, english in sorted(matches, key=lambda pair: len(pair[0]), reverse=True):
        if any(arabic in chosen_arabic for chosen_arabic, _ in selected):
            continue
        selected.append((arabic, english))
    terms: list[str] = []
    for _, english in selected:
        for token in normalized(english).split():
            if token not in terms:
                terms.append(token)
    return " ".join(terms)


def arabic_identity_tokens(name: str) -> set[str]:
    ignored = {"جم", "جرام", "كجم", "كيلو", "مل", "مللي", "لتر", "عبوة", "حبه", "حبات"}
    return {
        token for token in normalized(name).split()
        if re.search(r"[\u0600-\u06ff]", token)
        and token not in ignored
        and not token.isdigit()
    }

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


# Search aliases help the external catalog find common Egyptian grocery
# products even when the local Arabic item name is not represented verbatim.
# These are query expansions only; they do NOT bypass the strict identity checks
# in choose_image(), and therefore cannot make an unrelated image acceptable.
SEARCH_QUERY_ALIASES = {
    "أرز أبيض مصري": ["Egyptian white rice", "Calrose rice Egypt"],
    "أرز مصري عريض": ["Egyptian rice", "Calrose rice Egypt"],
    "بسكويت سادة": ["plain biscuits Egypt", "plain tea biscuits"],
    "بسكويت مالح": ["salted crackers Egypt", "savory biscuits"],
    "بسلة معلبة": ["canned green peas", "canned peas Egypt"],
    "بهارات مشكلة": ["mixed spices Egypt", "mixed seasoning spices"],
    "بيكنج بودر": ["baking powder Egypt", "baking powder sachet"],
    "تمر معبأ": ["packaged dates Egypt", "dates package"],
    "جبنة رومي": ["Egyptian Roumy cheese", "Roumy cheese"],
    "جبنة مطبوخة مثلثات": ["processed cheese triangles", "triangle cheese portions"],
    "بقسماط مطحون": ["ground breadcrumbs", "ground bread crumbs"],
    "توست حبوب كاملة": ["wholegrain toast", "whole wheat toast"],
    "كعك سادة معبأ": ["plain packaged biscuits", "plain tea biscuits"],
    "جوز هند مبشور": ["desiccated coconut", "shredded coconut"],
    "جيلاتين حلويات": ["unflavoured gelatin powder", "gelatin dessert powder"],
    "خميرة فورية": ["instant dry yeast sachet", "instant yeast"],
    "فانيليا": ["vanilla powder sachet", "vanilla sugar sachet"],
    "حلوى جيلي": ["jelly candy", "fruit jelly sweets"],
    "لبان نعناع": ["mint chewing gum", "mint gum"],
    "مصاصات": ["lollipop candy", "fruit lollipops"],
    "تونة قطع": ["canned tuna chunks", "tuna chunks in brine"],
    "ذرة حلوة معلبة": ["canned sweet corn", "sweet corn tin"],
    "صلصة طماطم": ["tomato sauce jar", "tomato paste can"],
    "فاصوليا حمراء معلبة": ["canned red kidney beans", "red kidney beans tin"],
    "فطر شرائح معلب": ["canned sliced mushrooms", "sliced mushrooms tin"],
    "فول مدمس معلب": ["canned fava beans", "Egyptian ful medames can"],
    "سبريد شوكولاتة": ["chocolate spread", "chocolate hazelnut spread"],
    "شوكولاتة بالبندق": ["hazelnut chocolate", "chocolate with hazelnuts"],
    "شوكولاتة بالحليب": ["milk chocolate bar", "milk chocolate"],
    "شوكولاتة داكنة": ["dark chocolate bar", "dark chocolate"],
    "زبادي": ["plain yogurt cup", "yogurt cup"],
    "قشطة": ["cream dairy product", "clotted cream"],
    "كريمة طبخ": ["cooking cream carton", "culinary cream"],
    "لبن خالي الدسم": ["skimmed milk carton", "fat free milk"],
    "لبن طويل الأجل": ["UHT milk carton", "long life milk"],
    "لبن كامل الدسم": ["whole milk carton", "full fat milk"],
    "تمر جاف": ["dried dates", "dry dates pack"],
    "عجوة تمر": ["date paste", "date spread"],
    "دقيق ذرة": ["corn flour pack", "maize flour"],
    "دقيق فاخر": ["wheat flour bag", "all purpose flour"],
    "سكر أبيض": ["white sugar bag", "granulated white sugar"],
    "ملح طعام": ["table salt pack", "fine salt"],
    "نشا ذرة": ["corn starch pack", "cornstarch"],
    "خضار مشكل مجمد": ["frozen mixed vegetables", "mixed vegetables frozen pack"],
}


def off_candidates(item: dict[str, Any]) -> list[dict[str, Any]]:
    barcode = str(item.get("barcode") or "").strip()
    name = str(item.get("item_name") or "").strip()
    brand = str(item.get("brand_name") or "").strip()
    searches = [barcode] if barcode else []
    if name:
        searches.append(" ".join(part for part in (brand, name) if part))
        searches.append(name)
        english = english_terms_for_name(name)
        if english:
            searches.append(" ".join(part for part in (brand, english) if part))
        for arabic_name, aliases in SEARCH_QUERY_ALIASES.items():
            if normalized(arabic_name) in normalized(name):
                searches.extend(aliases)
                break
    # Avoid querying the same Arabic name twice; this also respects the public
    # search API's rate limit and makes the validation loop faster.
    searches = list(dict.fromkeys(term.strip() for term in searches if term.strip()))
    found: list[dict[str, Any]] = []
    seen: set[str] = set()
    for term in searches:
        params = urllib.parse.urlencode({
            "q": term,
            "page_size": "12",
            "page": "1",
            "langs": "en,ar",
            "fields": "code,product_name,product_name_en,brands,image_front_url,image_front_small_url,image_url,countries_tags",
        })
        try:
            data = request_json(f"{OFF_API}?{params}")
        except urllib.error.HTTPError as exc:
            print(f"  SOURCE HTTP ERROR for query {term!r}: HTTP {exc.code} {exc.reason}")
            continue
        except (urllib.error.URLError, TimeoutError, json.JSONDecodeError) as exc:
            print(f"  SOURCE REQUEST ERROR for query {term!r}: {type(exc).__name__}: {exc}")
            continue
        finally:
            time.sleep(7.2)
        products = data.get("hits", data.get("products", []))
        if not products:
            print(f"  SOURCE returned 0 results for query {term!r} (status OK)")
        for product in products:
            code = str(product.get("code") or "")
            if code and code not in seen:
                seen.add(code)
                found.append(product)
    return found

def image_digest(data: bytes) -> str:
    """Stable content fingerprint, independent of source URL or product code."""
    return hashlib.sha256(data).hexdigest()


def image_data_digest(value: Any) -> str | None:
    """Fingerprint a PostgREST bytea value when it is returned as \\x-hex."""
    if not value:
        return None
    raw = str(value)
    if raw.startswith("\\x"):
        try:
            return image_digest(bytes.fromhex(raw[2:]))
        except ValueError:
            return None
    return None


def image_variant_matches(item_name: str, product_title: str) -> bool:
    """Reject a candidate if a distinguishing variant is absent or contradicted."""
    item = normalized(item_name)
    title = normalized(product_title)
    # Each tuple is (Arabic item markers, required English title markers,
    # mutually-conflicting English markers). Conservative by design: uncertain
    # packaging/processing variants must remain unmatched instead of being guessed.
    variants = [
        (("جاف", "جافة", "مجفف", "مجففة"), {"dried"}, {"fresh", "freshly"}),
        (("معبأ", "معبأة", "مغلف", "مغلفة"), {"packaged"}, set()),
        (("مجمد", "مجمدة", "مجمده"), {"frozen"}, {"fresh", "canned", "tinned"}),
        (("معلب", "معلبة", "معلبات"), {"canned"}, {"frozen", "fresh", "dried"}),
        (("مطحون", "مطحونة"), {"ground"}, {"whole", "wholegrain", "wholemeal"}),
        (("سادة",), {"plain"}, {"salted", "chocolate", "flavored", "flavoured"}),
        (("مالح", "مالحة"), {"salted"}, {"sweet", "plain", "unsalted"}),
        (("أبيض", "ابيض", "بيضاء"), {"white"}, {"brown", "wholegrain", "wholemeal"}),
        (("حبوب كاملة", "كامل الحبوب"), {"wholegrain"}, {"white", "refined"}),
        (("شرائح", "شريحة"), {"sliced"}, {"whole", "block"}),
        (("مثلثات", "مثلث"), {"triangle"}, set()),
        (("بالشوكولاتة", "شوكولاتة"), {"chocolate"}, {"plain", "vanilla"}),
        (("قابلة للدهن",), {"spreadable"}, {"sliced", "block"}),
    ]
    title_tokens = set(title.split())
    for arabic_markers, required, conflicts in variants:
        if any(normalized(marker) in item for marker in arabic_markers):
            # The source may describe the same pack in Arabic or English.
            # Require explicit evidence of the variant in either language.
            arabic_variant = any(
                set(normalized(marker).split()).issubset(title_tokens)
                for marker in arabic_markers
            )
            if not required.issubset(title_tokens) and not arabic_variant:
                return False
            if title_tokens & conflicts:
                return False
    # Dried and packaged dates are distinct variants; accept explicit evidence
    # in either language, but never let one variant stand in for the other.
    if "تمر" in item or "dates" in item.split():
        if any(marker in item for marker in ("جاف", "جافة", "مجفف")):
            if "dried" not in title_tokens and not ({"جاف", "جافة", "مجفف", "مجففة"} & title_tokens):
                return False
        if any(marker in item for marker in ("معبأ", "معبأة")):
            if "packaged" not in title_tokens and not ({"معبأ", "معبأة", "مغلف", "مغلفة"} & title_tokens):
                return False
    return True


def choose_image(
    item: dict[str, Any],
    candidates: list[dict[str, Any]],
    used_image_digests: set[str] | None = None,
) -> tuple[dict[str, Any], bytes, str] | None:
    used_image_digests = used_image_digests or set()
    barcode = str(item.get("barcode") or "").strip()
    raw_name = str(item.get("item_name") or "")
    raw_brand = str(item.get("brand_name") or "")
    english_terms = english_terms_for_name(raw_name)
    target = normalized(" ".join((raw_brand, raw_name, english_terms)))
    has_latin_name = bool(re.search(r"[a-zA-Z]", raw_name))
    generic_mode = not barcode and not raw_brand and not has_latin_name
    required = set(normalized(english_terms).split())
    identity_arabic = arabic_identity_tokens(raw_name)
    exclusions = {
        "rice": {"cake", "cakes", "noodle", "noodles", "cracker", "crackers", "flour", "milk", "drink"},
        # Corn tortillas contain both "corn" and "flour" but are not corn flour.
        "flour": {"tortilla", "tortillas", "wrap", "wraps", "flatbread"},
        "basmati": {"flavor", "flavoured", "flavored"},
        "pasta": {"sauce", "seasoning"},
        "milk": {"chocolate", "soap", "shampoo"},
        "water": {"flavor", "flavoured", "flavored"},
        "lupini": {"garlic", "rosemary", "snacking", "snack", "seasoning", "flavored", "flavoured"},
        "gelatin": {"strawberry", "banana", "orange", "lemon", "mango", "flavored", "flavoured"},
    }
    best = None
    best_score = 0.0
    rejects = {"variant": 0, "identity": 0, "excluded": 0, "origin": 0, "score": 0, "no_url": 0, "bad_image": 0, "duplicate": 0}
    for candidate in candidates:
        code = str(candidate.get("code") or "")
        product_title = normalized(" ".join(str(candidate.get(k) or "") for k in ("product_name", "product_name_en")))
        brands = normalized(str(candidate.get("brands") or ""))
        title = normalized(" ".join((product_title, brands)))
        title_tokens = set(title.split())
        product_tokens = set(product_title.split())
        arabic_candidate = arabic_identity_tokens(product_title)
        if not image_variant_matches(raw_name, product_title):
            rejects["variant"] += 1
            continue
        if barcode and code == barcode:
            score = 1.0
        elif generic_mode:
            # Require every distinguishing English term (e.g. "salted biscuits"
            # or "Egyptian white rice"), or a full Arabic identity match. This
            # prevents reusing one generic package for different variants.
            english_match = bool(required) and required.issubset(title_tokens)
            arabic_match = bool(identity_arabic) and identity_arabic.issubset(arabic_candidate)
            if not english_match and not arabic_match:
                rejects["identity"] += 1
                continue
            blocked = set().union(*(exclusions.get(term, set()) for term in required))
            if product_tokens & blocked:
                rejects["excluded"] += 1
                continue
            # If the ERP name says Egyptian, don't accept a package with no
            # Egyptian indication in its title/country metadata.
            if "مصري" in raw_name:
                countries = " ".join(str(x) for x in candidate.get("countries_tags", []) or [])
                if not ({"egyptian", "egypt"} & title_tokens or "egypt" in countries.casefold()):
                    if not arabic_match or "مصري" not in arabic_candidate:
                        rejects["origin"] += 1
                        continue
            score = 1.0 if arabic_match else len(required & title_tokens) / max(1, len(required))
        else:
            a, b = set(target.split()), set(title.split())
            score = len(a & b) / max(1, len(a | b))
            brand = normalized(raw_brand)
            if brand and brand in brands:
                score += 0.25
            if not brand and english_terms and not (set(normalized(english_terms).split()) & set(product_title.split())):
                score = min(score, 0.25)
        threshold = 0.95 if generic_mode else (0.48 if not barcode and not raw_brand and not has_latin_name else 0.42)
        if score < threshold or score <= best_score:
            rejects["score"] += 1
            continue
        image_url = candidate.get("image_front_url") or candidate.get("image_url")
        if not image_url:
            rejects["no_url"] += 1
            continue
        image = download_image(str(image_url))
        if not image:
            rejects["bad_image"] += 1
            continue
        if image:
            # Different source records can still point to identical bytes.
            # Never assign an already-used product-pack image to another item.
            if image_digest(image[0]) in used_image_digests:
                print(f"  DUPLICATE IMAGE BLOCKED: source code {code} reuses an existing image")
                rejects["duplicate"] += 1
                continue
            best, best_score = (candidate, image[0], image[1]), score
    if best is None:
        print("  REJECTION COUNTS: " + ", ".join(f"{key}={value}" for key, value in rejects.items()))
    return best

GROUP_ITEM_HINTS = {
    "FOOD-GHEE": ["سمن", "ghee"],
    "FOOD-OILS": ["زيت", "oil"],
    "FOOD-PASTA": ["مكرونة", "pasta", "نودلز"],
    "FOOD-LEGUMES": ["عدس", "فول", "حمص", "فاصوليا", "لوبيا", "ترمس", "lentils", "beans", "chickpeas", "lupini"],
    "FOOD-HOT-DRINKS": ["شاي", "قهوة", "tea", "coffee"],
    "FOOD-SOFT-DRINKS": ["مشروب", "مياه", "soda", "water"],
    "FOOD-CHEESE": ["جبن", "جبنة", "cheese"],
    "FOOD-DAIRY": ["لبن", "زبادي", "milk", "yogurt"],
    "FOOD-JUICES": ["عصير", "juice"],
    "FOOD-SNACKS": ["مقرمشات", "شيبسي", "بسكويت", "chips", "snack", "biscuit"],
    "FOOD-CANNED": ["معلبة", "معلبات", "تونة", "canned", "tuna"],
    "FOOD-CHOCOLATE": ["شوكولاتة", "شيكولاتة", "chocolate"],
    "FOOD-CANDY": ["حلويات", "حلوى", "توفي", "candy", "jelly", "toffee"],
    "FOOD-FROZEN": ["مجمد", "frozen"],
    "FOOD-RICE": ["أرز", "برغل", "rice", "bulgur"],
    "FOOD-BAKERY": ["توست", "خبز", "بقسماط", "toast", "bread", "breadcrumbs"],
    "FOOD-DATES": ["تمر", "dates"],
    "FOOD-JAMS": ["مربى", "عسل", "jam", "honey", "spread"],
    "FOOD-SPICES": ["بهارات", "توابل", "spices", "seasoning"],
    "FOOD-BAKING": ["بيكنج بودر", "جيلاتين", "baking powder", "gelatin"],
    "FOOD-NUTRITION": ["إفطار", "جرانولا", "شوفان", "cereal", "granola", "oats"],
    "FOOD-NUTS": ["مكسرات", "جوز هند", "nuts", "coconut"],
    "FOOD-PICKLES": ["مخلل", "زيتون", "pickles", "olives"],
    "FOOD-SAUCE": ["صلصة", "كاتشب", "مايونيز", "sauce", "ketchup", "mayonnaise"],
    "FOOD-FLOUR-SUGAR": ["دقيق", "سكر", "flour", "sugar"],
    "JUICE-JUHAINA": ["جهينه", "juhayna"],
    "JUICE-BETTY": ["بيتي", "betty"],
    "BISCUIT-LAMBADA": ["بسكويت", "lambada", "biscuit"],
    "CHEESE-RHODES": ["جبن", "جبنة", "rhodes", "cheese"],
}


def group_image_matches_item(group_code: str, item_name: str, product: dict[str, Any]) -> bool:
    hints = GROUP_ITEM_HINTS.get(group_code)
    if not hints:
        return False
    item_text = normalized(item_name)
    product_text = normalized(" ".join((
        str(product.get("product_name") or ""),
        str(product.get("product_name_en") or ""),
        str(product.get("brands") or ""),
    )))
    # The ERP item itself must belong to this group, and the source product must
    # independently confirm that same family. A broad word such as "spread"
    # in a halva title cannot classify halva as jam/honey.
    item_matches = any(normalized(hint) in item_text for hint in hints)
    product_matches = any(normalized(hint) in product_text for hint in hints)
    if not item_matches or not product_matches:
        return False
    return image_variant_matches(item_name, product_text)


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
        "FOOD-RICE": ["أرز وحبوب"],
        "FOOD-FLOUR-SUGAR": ["دقيق وسكر"],
        "FOOD-BAKERY": ["مخبوزات"],
        "FOOD-BAKING": ["مكملات حلويات"],
        "FOOD-DATES": ["تمر"],
        "FOOD-JAMS": ["مربى وعسل"],
        "FOOD-NUTS": ["مكسرات وفواكه مجففة"],
        "FOOD-NUTRITION": ["إفطار وحبوب إفطار", "مكملات طعام"],
        "FOOD-PICKLES": ["مخللات وزيتون"],
        "FOOD-SAUCE": ["صلصات وتوابل"],
        "FOOD-SPICES": ["بهارات وتوابل"],
        "JUICE-BETTY": ["عصائر"],
        "JUICE-JUHAINA": ["عصائر"],
        "BISCUIT-LAMBADA": ["مقرمشات"],
        "CHEESE-RHODES": ["جبن"],
        "HOME-AIR": ["منظفات"],
        "HOME-KITCHEN": ["خردوات"],
        "HOME-TOOLS": ["خردوات"],
        "BABY-CARE": ["مستلزمات أطفال"],
        "PET-FOOD": ["أصناف أخرى"],
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
        "select": "id,item_code,item_name,barcode,brand_name,group_id,image_data,image_url,source_url",
        "order": "item_name.asc",
        "limit": "500",
    }))
    group_by_id = {g["id"]: g for g in groups}
    # Seed both guards from the entire ERP catalog before slicing the next
    # batch. Source-code uniqueness alone is insufficient because two records
    # may use different product codes but serve identical image bytes.
    used_source_codes: set[str] = set()
    used_image_digests: set[str] = set()
    for row in items:
        source_match = re.search(r"/product/([^/?#]+)", str(row.get("source_url") or ""))
        if source_match:
            used_source_codes.add(source_match.group(1))
        # Guard every existing real-size item image, not just rows whose source
        # provenance URL is recognized. A copied image is still a duplicate.
        stored_image = str(row.get("image_data") or "")
        if len(stored_image) > 25_000:
            digest = image_data_digest(stored_image)
            if digest:
                used_image_digests.add(digest)
    # The alphabetic first page was dominated by household goods. Inspect the
    # full ERP catalog, then prioritize food groups and records without real photos.
    def item_priority(row: dict[str, Any]) -> tuple[int, int, str]:
        group = group_by_id.get(row.get("group_id"), {})
        group_code = str(group.get("group_code") or "")
        image_size = len(str(row.get("image_data") or ""))
        has_good_image = image_size > 25_000
        return (0 if group_code.startswith("FOOD-") else 1, 1 if has_good_image else 0, str(row.get("item_name") or ""))

    items.sort(key=item_priority)
    items = items[:MAX_ITEMS]
    print(f"ERP groups: {len(groups)}; items checked: {len(items)} (food groups prioritized)")
    refreshed_groups: set[str] = set()
    updated = 0
    for index, item in enumerate(items, 1):
        # Existing photos smaller than the quality threshold are considered placeholders.
        old = str(item.get("image_data") or "")
        if len(old) > 25_000:
            continue
        item_name = str(item.get("item_name") or "(unnamed)")
        candidates = off_candidates(item)
        candidates = [candidate for candidate in candidates if str(candidate.get("code") or "") not in used_source_codes]
        print(f"[{index}/{len(items)}] Checking: {item_name} | barcode={'yes' if item.get('barcode') else 'no'} | brand={'yes' if item.get('brand_name') else 'no'} | source candidates={len(candidates)}")
        match = choose_image(item, candidates, used_image_digests)
        if not match:
            # Surface a small set of candidate titles to make matching failures
            # actionable without flooding workflow logs or relaxing identity checks.
            diagnostic = []
            for candidate in candidates:
                title = " ".join(str(candidate.get(k) or "") for k in ("product_name", "product_name_en")).strip()
                if title and (candidate.get("image_front_url") or candidate.get("image_url")):
                    diagnostic.append(title[:100])
                if len(diagnostic) >= 4:
                    break
            suffix = f"; image-bearing candidates={diagnostic}" if diagnostic else ""
            print(f"  NO MATCH: {item_name} (no candidate passed identity, image-size, and image-quality checks){suffix}")
            continue
        product, image_bytes, mime = match
        product_code = str(product.get("code") or "")
        if product_code:
            used_source_codes.add(product_code)
        used_image_digests.add(image_digest(image_bytes))
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
        group = group_by_id.get(group_id) if group_id else None
        group_code = str((group or {}).get("group_code") or "")
        representative = group_image_matches_item(group_code, item_name, product)
        if group_id and group_id not in refreshed_groups and representative:
            refreshed_groups.add(group_id)
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
