"""Safety tests for real catalog image matching; no network or database access."""
import importlib.util
import unittest
from pathlib import Path
from unittest.mock import patch

SCRIPT = Path(__file__).with_name("import_real_product_images.py")
SPEC = importlib.util.spec_from_file_location("catalog_importer", SCRIPT)
IMPORTER = importlib.util.module_from_spec(SPEC)
assert SPEC and SPEC.loader
SPEC.loader.exec_module(IMPORTER)


class CatalogImageMatchingTests(unittest.TestCase):
    def test_dried_dates_cannot_match_packaged_dates(self):
        self.assertFalse(
            IMPORTER.image_variant_matches("تمر جاف", "Packaged dates")
        )
        self.assertFalse(
            IMPORTER.image_variant_matches("تمر معبأ", "Dried dates")
        )

    def test_packaged_dates_require_packaging_evidence(self):
        self.assertFalse(IMPORTER.image_variant_matches("تمر معبأ", "Dates"))
        self.assertTrue(
            IMPORTER.image_variant_matches("تمر معبأ", "Packaged dates")
        )
        self.assertTrue(
            IMPORTER.image_variant_matches("تمر معبأ", "تمر معبأ 1 كجم")
        )

    def test_explicit_arabic_variant_evidence_is_accepted_without_cross_variant_match(self):
        self.assertTrue(
            IMPORTER.image_variant_matches("بسلة مجمدة", "بسلة مجمدة 400 جم")
        )
        self.assertFalse(
            IMPORTER.image_variant_matches("بسلة مجمدة", "بسلة معلبة 400 جم")
        )
        self.assertTrue(
            IMPORTER.image_variant_matches("بسكويت سادة", "بسكويت سادة")
        )

    def test_halva_is_not_a_jam_or_honey_group_representative(self):
        halva = {
            "product_name": "Tahini halva spread",
            "product_name_en": "Tahini halva",
            "brands": "Example",
        }
        self.assertFalse(
            IMPORTER.group_image_matches_item("FOOD-JAMS", "حلاوة طحينية", halva)
        )

    def test_group_representative_requires_item_and_source_to_match_group(self):
        jam = {"product_name": "Strawberry jam", "product_name_en": "Jam"}
        self.assertTrue(
            IMPORTER.group_image_matches_item("FOOD-JAMS", "مربى فراولة", jam)
        )
        self.assertFalse(
            IMPORTER.group_image_matches_item("FOOD-JAMS", "حلاوة طحينية", jam)
        )

    def test_duplicate_image_bytes_are_rejected_even_with_different_source_code(self):
        item = {"item_name": "تمر جاف", "barcode": "", "brand_name": ""}
        candidate = {
            "code": "different-off-code",
            "product_name": "Dried dates",
            "product_name_en": "Dried dates",
            "brands": "",
            "image_front_url": "https://images.example.test/dates.jpg",
        }
        image_bytes = b"same-real-image-bytes"
        with patch.object(IMPORTER, "download_image", return_value=(image_bytes, "image/jpeg")):
            match = IMPORTER.choose_image(
                item, [candidate], {IMPORTER.image_digest(image_bytes)}
            )
        self.assertIsNone(match)

    def test_clear_200px_product_packshot_passes_image_quality_gate(self):
        payload = bytearray(8500)
        payload[0:8] = b"\x89PNG\r\n\x1a\n"
        payload[16:20] = (200).to_bytes(4, "big")
        payload[20:24] = (200).to_bytes(4, "big")

        class FakeResponse:
            headers = None

            def __init__(self, body):
                self.body = body
                self.headers = self

            def __enter__(self):
                return self

            def __exit__(self, *args):
                return False

            def read(self, limit):
                return bytes(self.body)

            def get_content_type(self):
                return "image/png"

        with patch.object(
            IMPORTER.urllib.request, "urlopen", return_value=FakeResponse(payload)
        ):
            result = IMPORTER.download_image("https://example.test/product.png")
        self.assertEqual(result, (bytes(payload), "image/png"))

    def test_webp_vp8l_dimensions_are_read(self):
        data = bytearray(25)
        data[0:4] = b"RIFF"
        data[8:12] = b"WEBP"
        data[12:16] = b"VP8L"
        data[20] = 0x2F
        data[21] = 0x7F
        data[22] = 0xC2
        data[23] = 0x77
        data[24] = 0x00
        self.assertEqual(IMPORTER.image_dimensions(bytes(data), "image/webp"), (640, 480))

    def test_webp_vp8_dimensions_are_read(self):
        data = bytearray(30)
        data[0:4] = b"RIFF"
        data[8:12] = b"WEBP"
        data[12:16] = b"VP8 "
        data[23:26] = bytes((0x9D, 0x01, 0x2A))
        data[26:28] = (640).to_bytes(2, "little")
        data[28:30] = (480).to_bytes(2, "little")
        self.assertEqual(IMPORTER.image_dimensions(bytes(data), "image/webp"), (640, 480))

    def test_stored_bytea_threshold_matches_minimum_photo_size(self):
        good = "\\x" + ("ab" * IMPORTER.MIN_BYTES)
        small = "\\x" + ("ab" * (IMPORTER.MIN_BYTES - 1))
        self.assertTrue(IMPORTER.has_real_size_image(good))
        self.assertFalse(IMPORTER.has_real_size_image(small))

    def test_remaining_food_aliases_expand_search_without_relaxing_identity(self):
        requested_queries = []

        def empty_search(url):
            requested_queries.append(
                IMPORTER.urllib.parse.parse_qs(IMPORTER.urllib.parse.urlparse(url).query)["q"][0]
            )
            return {"hits": []}

        with patch.object(IMPORTER, "request_json", side_effect=empty_search), patch.object(
            IMPORTER.time, "sleep"
        ):
            for name in ("لب سوري 200 جم", "قهوة مطحونة 250 جم", "مربى مشمش 400 جم"):
                self.assertEqual(
                    IMPORTER.off_candidates(
                        {"item_name": name, "barcode": "", "brand_name": ""}
                    ),
                    [],
                )

        self.assertIn("sunflower seeds roasted", requested_queries)
        self.assertIn("ground coffee pack", requested_queries)
        self.assertIn("apricot jam jar", requested_queries)
        self.assertFalse(
            IMPORTER.image_variant_matches("لب سوري", "plain corn flakes")
        )
        self.assertFalse(
            IMPORTER.image_variant_matches("مربى مشمش", "strawberry jam")
        )

    def test_iced_tea_beverage_does_not_match_loose_tea_pack(self):
        self.assertFalse(
            IMPORTER.image_variant_matches("شاي ناعم 250 جم", "Fuze Tea Peach")
        )
        self.assertFalse(
            IMPORTER.image_variant_matches(
                "شاي أسود 40 فتلة",
                "Thé infusé glacé, Thé noir parfum pêche blanche",
            )
        )
        self.assertTrue(
            IMPORTER.image_variant_matches("شاي ناعم 250 جم", "Loose black tea 250g")
        )
        self.assertTrue(
            IMPORTER.image_variant_matches("شاي أسود 40 فتلة", "Black tea bags 40")
        )

    def test_sweet_potato_chips_do_not_match_regular_potato_chips(self):
        self.assertFalse(
            IMPORTER.image_variant_matches("رقائق بطاطس ملح", "sweet potato chips")
        )
        self.assertTrue(
            IMPORTER.image_variant_matches("رقائق بطاطا حلوة", "sweet potato chips")
        )

    def test_corn_tortillas_are_not_accepted_as_corn_flour(self):
        item = {"item_name": "دقيق ذرة 500 جم", "barcode": "", "brand_name": ""}
        candidate = {
            "code": "tortilla-product",
            "product_name": "Flour & corn tortillas",
            "product_name_en": "Flour & corn",
            "brands": "",
            "image_front_url": "https://images.example.test/tortillas.jpg",
        }
        with patch.object(IMPORTER, "download_image") as download:
            match = IMPORTER.choose_image(item, [candidate])
        self.assertIsNone(match)
        download.assert_not_called()

    def test_postgrest_bytea_hash_matches_original_bytes(self):
        raw = b"stored-photo"
        value = "\\x" + raw.hex()
        self.assertEqual(
            IMPORTER.image_data_digest(value), IMPORTER.image_digest(raw)
        )

    def test_egyptian_grocery_aliases_expand_search_without_relaxing_matching(self):
        item = {"item_name": "أرز أبيض مصري", "barcode": "", "brand_name": ""}
        requested_queries = []

        def empty_search(url):
            requested_queries.append(
                IMPORTER.urllib.parse.parse_qs(IMPORTER.urllib.parse.urlparse(url).query)["q"][0]
            )
            return {"hits": []}

        with patch.object(IMPORTER, "request_json", side_effect=empty_search), patch.object(
            IMPORTER.time, "sleep"
        ):
            self.assertEqual(IMPORTER.off_candidates(item), [])

        self.assertIn("Egyptian white rice", requested_queries)
        self.assertIn("Calrose rice Egypt", requested_queries)
        # Search expansion alone must not allow a contradictory candidate.
        self.assertFalse(
            IMPORTER.image_variant_matches("أرز أبيض مصري", "brown rice")
        )

    def test_common_grocery_aliases_expand_search_without_weakening_identity(self):
        item = {"item_name": "فطر شرائح معلب 400 جم", "barcode": "", "brand_name": ""}
        requested_queries = []

        def empty_search(url):
            requested_queries.append(
                IMPORTER.urllib.parse.parse_qs(IMPORTER.urllib.parse.urlparse(url).query)["q"][0]
            )
            return {"hits": []}

        with patch.object(IMPORTER, "request_json", side_effect=empty_search), patch.object(
            IMPORTER.time, "sleep"
        ):
            self.assertEqual(IMPORTER.off_candidates(item), [])

        self.assertIn("canned sliced mushrooms", requested_queries)
        self.assertIn("sliced mushrooms tin", requested_queries)
        self.assertFalse(
            IMPORTER.image_variant_matches("فطر شرائح معلب", "fresh whole mushrooms")
        )


if __name__ == "__main__":
    unittest.main(verbosity=2)
