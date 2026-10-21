# Real product image enrichment

This tool is the first controlled step in replacing 72×72 placeholder artwork in the ERP catalog with genuine product-pack photography. It **downloads image bytes and writes them into PostgreSQL `bytea` columns** (`erp_items.image_data`, and representative images to `erp_item_groups.image_data`); it does not save the image URL as the image itself. The source product page is retained separately for provenance.

## Source and rights

The current adapter uses the Open Food Facts public API as an opt-in source for products that can be matched confidently. It is **not an Amazon.eg import**, and it will not pretend an unmatched item is a verified product. Open Food Facts product data is shared under the Open Database License (ODbL); product images may have their own Creative Commons terms. Review the specific product/image license and attribution requirements before commercial reuse. See:
- https://world.openfoodfacts.org/terms-of-use
- https://world.openfoodfacts.org/data

For a production-scale Egyptian catalog, prefer authorized manufacturer/distributor image packs or a licensed product-data feed. Amazon.eg must be integrated through an authorized API/feed or permissioned export rather than copying protected images indiscriminately. Prices should be imported only with a seller/source and retrieval timestamp; this image tool deliberately does not invent prices.

## Run safely

Requires Python 3.10+ and no third-party Python packages.

Set environment variables in a secure terminal (never commit secrets):
- `SUPABASE_URL`: the project's Supabase URL.
- `SUPABASE_SERVICE_ROLE_KEY`: server-side service role key. Never use this key in Flutter or a public repository.
- `SILSILA_ERP_COMPANY_ID`: the target ERP company UUID.
- Optional `SILSILA_IMAGE_IMPORT_LIMIT`: number of existing ERP items to inspect (default 250).

The script starts in **dry-run mode**:
```bash
python tools/catalog_import/import_real_product_images.py
```

Inspect the matched product names, image sizes and provenance before applying changes. To write images, explicitly set:
```bash
SILSILA_IMAGE_IMPORT_DRY_RUN=0 python tools/catalog_import/import_real_product_images.py
```

On PowerShell:
```powershell
$env:SUPABASE_IMAGE_IMPORT_DRY_RUN = "0"
```

Use the actual variable name `SILSILA_IMAGE_IMPORT_DRY_RUN` (not the example alias above) and run the Python command. Keep the service key in a secure environment only.

## Safety and matching

- Existing ERP item rows only; no synthetic product, supplier, inventory, price, or public marketplace listing is created.
- Barcode matches are preferred. Name matches require a minimum similarity score.
- Downloads must be HTTPS, be a recognized image format, exceed the minimum dimensions and size, and stay below 4 MB.
- Unmatched items remain unchanged. Existing sufficiently large images remain unchanged.
- Image bytes are stored in `image_data`; `image_url` is cleared for replaced images.
- The source product page is stored in `source_url` for auditability, not as a display image.
- Test on a small batch and inspect records in the app before running a larger import.

## Known limitation

Open Food Facts coverage for Egyptian wholesale packs is incomplete. This is an enrichment pipeline, not a claim that every current Silsila item has been verified or that the entire Amazon Egypt supermarket catalog has been imported. A second phase should add a licensed Egyptian source, validate category hierarchy and pack sizes, and publish products only through the existing supplier approval/workflow.
