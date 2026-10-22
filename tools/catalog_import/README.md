# Real product image enrichment

This tool is the first controlled step in replacing 72×72 placeholder artwork in the ERP catalog with genuine product-pack photography. It **downloads image bytes and writes them into PostgreSQL `bytea` columns** (`erp_items.image_data`, and representative images to `erp_item_categories.image_data`); it does not save the image URL as the image itself. The source product page is retained separately for provenance.

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

On PowerShell, set the variable with the correct name:
```powershell
$env:SILSILA_IMAGE_IMPORT_DRY_RUN = "0"
python tools/catalog_import/import_real_product_images.py
```

Keep the service key in a secure environment only.

## Safety and matching

- A SHA-256 fingerprint blocks reuse of identical image bytes for different ERP items, even when the source API returns different product codes or URLs.
- Variant markers are enforced before a match is accepted. For example, `تمر جاف` requires evidence for dried dates and `تمر معبأ` requires evidence for packaged dates; uncertain matches remain unchanged.
- Group representative photos require both the ERP item's own name and the source product title to match the same category. A halva title containing a broad word such as “spread” cannot qualify as a jam/honey representative.
- The manual workflow runs offline unit tests before making any API requests. Tests cover date variants, category mismatch, duplicate image bytes and PostgreSQL bytea fingerprints.
- Existing ERP item rows only; no synthetic product, supplier, inventory, price, or public marketplace listing is created.
- Barcode matches are preferred. Name matches require a minimum similarity score.
- Downloads must be HTTPS, be a recognized image format, exceed the minimum dimensions and size, and stay below 4 MB.
- Unmatched items remain unchanged. Existing sufficiently large images remain unchanged.
- Image bytes are stored in `image_data`; `image_url` is cleared for replaced images.
- The source product page is stored in `source_url` for auditability, not as a display image.
- Test on a small batch and inspect records in the app before running a larger import.

## Known limitation

Open Food Facts coverage for Egyptian wholesale packs is incomplete. This is an enrichment pipeline, not a claim that every current Silsila item has been verified or that the entire Amazon Egypt supermarket catalog has been imported. A second phase should add a licensed Egyptian source, validate category hierarchy and pack sizes, and publish products only through the existing supplier approval/workflow.


## Run from GitHub Actions

A manual workflow is available at **Actions → Enrich Silsila catalog images**:
https://github.com/silsilafoodstuffs-creator/Silsila-App/actions/workflows/enrich-catalog-images.yml

1. Add the repository Actions secret `SUPABASE_SERVICE_ROLE_KEY` under Settings → Secrets and variables → Actions. Never place the key in code or Flutter.
2. Run the workflow first with `apply_images = false` and a small item limit. This is a dry run and does not write to Supabase.
3. Inspect logs for exact matched item names and image sizes.
4. Only if the matches are correct and image reuse is permitted, rerun with `apply_images = true`. Start with 10 items before expanding.
5. Check the Supabase image byte sizes and open the images in the app/ERP. A successful write alone does not prove a correct match.

The workflow has not run automatically: it is manual by design to avoid modifying production catalog images without a human review.
