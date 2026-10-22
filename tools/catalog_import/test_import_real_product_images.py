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

    def test_postgrest_bytea_hash_matches_original_bytes(self):
        raw = b"stored-photo"
        value = "\\x" + raw.hex()
        self.assertEqual(
            IMPORTER.image_data_digest(value), IMPORTER.image_digest(raw)
        )


if __name__ == "__main__":
    unittest.main(verbosity=2)
