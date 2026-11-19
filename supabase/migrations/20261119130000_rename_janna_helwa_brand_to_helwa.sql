BEGIN;

-- Consolidate the mistakenly added "جنة حلوة" brand into the existing
-- "حلوة" brand per company, preserving item and ticker references.
DO $rename_brand$
DECLARE
  v_source record;
  v_target_id uuid;
BEGIN
  FOR v_source IN
    SELECT id, company_id
    FROM public.erp_brands
    WHERE lower(btrim(brand_name)) = lower('جنة حلوة')
    FOR UPDATE
  LOOP
    SELECT id INTO v_target_id
    FROM public.erp_brands
    WHERE company_id = v_source.company_id
      AND lower(btrim(brand_name)) = lower('حلوة')
      AND id <> v_source.id
    LIMIT 1
    FOR UPDATE;

    IF v_target_id IS NULL THEN
      -- No existing "حلوة" row: a direct rename preserves code, logo and links.
      UPDATE public.erp_brands
      SET brand_name = 'حلوة'
      WHERE id = v_source.id AND company_id = v_source.company_id;
      CONTINUE;
    END IF;

    -- Preserve the source logo when the destination has no logo.
    UPDATE public.erp_brands dst
    SET logo_data = COALESCE(dst.logo_data, src.logo_data),
        logo_mime_type = CASE
          WHEN dst.logo_data IS NULL THEN src.logo_mime_type
          ELSE dst.logo_mime_type
        END
    FROM public.erp_brands src
    WHERE dst.id = v_target_id
      AND src.id = v_source.id
      AND dst.company_id = src.company_id;

    -- Avoid violating the unique ticker slot index if both brands occupy
    -- the same app/activity/slot; the existing destination assignment wins.
    DELETE FROM public.erp_app_ticker_ads src_ad
    WHERE src_ad.company_id = v_source.company_id
      AND src_ad.brand_id = v_source.id
      AND EXISTS (
        SELECT 1
        FROM public.erp_app_ticker_ads dst_ad
        WHERE dst_ad.app_id = src_ad.app_id
          AND dst_ad.activity_code IS NOT DISTINCT FROM src_ad.activity_code
          AND dst_ad.slot_no = src_ad.slot_no
          AND dst_ad.brand_id = v_target_id
      );

    UPDATE public.erp_app_ticker_ads
    SET brand_id = v_target_id
    WHERE company_id = v_source.company_id
      AND brand_id = v_source.id;

    -- Updating brand_id invokes the established item-code trigger, which
    -- regenerates item codes using the destination brand's configured code.
    UPDATE public.erp_items
    SET brand_id = v_target_id
    WHERE company_id = v_source.company_id
      AND brand_id = v_source.id;

    -- Remove the obsolete duplicate only after all known references migrate.
    DELETE FROM public.erp_brands
    WHERE id = v_source.id AND company_id = v_source.company_id;

    v_target_id := NULL;
  END LOOP;
END;
$rename_brand$;

DO $verify$
BEGIN
  IF EXISTS (
    SELECT 1 FROM public.erp_brands
    WHERE lower(btrim(brand_name)) = lower('جنة حلوة')
  ) THEN
    RAISE EXCEPTION 'Brand rename verification failed: "جنة حلوة" still exists';
  END IF;
END;
$verify$;

COMMIT;
