-- Activity-specific banners, popup ads, and an optional intro image/video.
ALTER TABLE public.erp_app_assets
  ADD COLUMN IF NOT EXISTS activity_code text;

ALTER TABLE public.erp_app_assets DROP CONSTRAINT IF EXISTS erp_app_assets_asset_type_check;
ALTER TABLE public.erp_app_assets ADD CONSTRAINT erp_app_assets_asset_type_check
  CHECK (asset_type IN (
    'app_logo','splash','app_icon','category','item','supplier','customer',
    'shipping_company','banner_ad','popup_ad','intro_ad','other'
  ));

CREATE INDEX IF NOT EXISTS erp_app_assets_activity_ads_idx
  ON public.erp_app_assets(app_id, activity_code, asset_type, display_name, created_at DESC)
  WHERE asset_type IN ('banner_ad','popup_ad','intro_ad');

GRANT SELECT ON public.erp_app_assets TO anon, authenticated;
DROP POLICY IF EXISTS erp_app_assets_public_banner_read ON public.erp_app_assets;
CREATE POLICY erp_app_assets_public_banner_read
ON public.erp_app_assets FOR SELECT TO anon, authenticated
USING (
  (asset_type = 'banner_ad' AND display_name IN ('إعلان 1','إعلان 2','إعلان 3','إعلان 4','إعلان 5'))
  OR (asset_type = 'popup_ad' AND display_name = 'إعلان منبثق')
  OR (asset_type = 'intro_ad' AND display_name = 'إعلان البداية')
);

DROP FUNCTION IF EXISTS public.get_silsila_public_ads();
CREATE OR REPLACE FUNCTION public.get_silsila_public_ads(p_activity_code text DEFAULT NULL)
RETURNS TABLE(
  display_name text,
  storage_path text,
  target_type text,
  target_code text,
  duration_seconds integer,
  mime_type text,
  activity_code text
)
LANGUAGE sql STABLE SECURITY INVOKER
SET search_path TO 'public'
AS $function$
  WITH specific AS (
    SELECT a.display_name, a.storage_path, a.target_type, a.target_code,
           a.duration_seconds, a.mime_type,
           row_number() OVER (ORDER BY a.display_name) AS rn
    FROM public.erp_app_assets a
    WHERE a.asset_type = 'banner_ad'
      AND p_activity_code IS NOT NULL
      AND a.activity_code = p_activity_code
      AND a.display_name IN ('إعلان 1','إعلان 2','إعلان 3','إعلان 4','إعلان 5')
  ),
  global_ads AS (
    SELECT a.display_name, a.storage_path, a.target_type, a.target_code,
           a.duration_seconds, a.mime_type,
           row_number() OVER (ORDER BY a.display_name) AS rn
    FROM public.erp_app_assets a
    WHERE a.asset_type = 'banner_ad'
      AND a.activity_code IS NULL
      AND a.display_name IN ('إعلان 1','إعلان 2','إعلان 3','إعلان 4','إعلان 5')
  ),
  combined AS (
    SELECT s.storage_path, s.target_type, s.target_code, s.duration_seconds, s.mime_type,
           s.rn AS output_rank, s.display_name, p_activity_code AS activity_code
    FROM specific s
    UNION ALL
    SELECT g.storage_path, g.target_type, g.target_code, g.duration_seconds, g.mime_type,
           (SELECT count(*) FROM specific) + g.rn AS output_rank,
           g.display_name, NULL::text AS activity_code
    FROM global_ads g
    WHERE g.rn <= 5 - (SELECT count(*) FROM specific)
  )
  SELECT ('إعلان ' || output_rank::text), storage_path, target_type, target_code,
         duration_seconds, mime_type, activity_code
  FROM combined
  WHERE output_rank <= 5
  ORDER BY output_rank;
$function$;
REVOKE ALL ON FUNCTION public.get_silsila_public_ads(text) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.get_silsila_public_ads(text) TO anon, authenticated;

DROP FUNCTION IF EXISTS public.get_silsila_public_popup_ads();
CREATE OR REPLACE FUNCTION public.get_silsila_public_popup_ads(p_activity_code text DEFAULT NULL)
RETURNS TABLE(display_name text, storage_path text, target_type text, target_code text, duration_seconds integer, mime_type text, activity_code text)
LANGUAGE sql STABLE SECURITY INVOKER
SET search_path TO 'public'
AS $function$
  SELECT a.display_name, a.storage_path, a.target_type, a.target_code, a.duration_seconds, a.mime_type, a.activity_code
  FROM public.erp_app_assets a
  WHERE a.asset_type = 'popup_ad' AND a.display_name = 'إعلان منبثق'
    AND (a.activity_code = p_activity_code OR a.activity_code IS NULL)
  ORDER BY CASE WHEN p_activity_code IS NOT NULL AND a.activity_code = p_activity_code THEN 0 ELSE 1 END,
           a.created_at DESC
  LIMIT 1;
$function$;
REVOKE ALL ON FUNCTION public.get_silsila_public_popup_ads(text) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.get_silsila_public_popup_ads(text) TO anon, authenticated;

CREATE OR REPLACE FUNCTION public.get_silsila_public_intro_ad(p_activity_code text DEFAULT NULL)
RETURNS TABLE(display_name text, storage_path text, target_type text, target_code text, duration_seconds integer, mime_type text, activity_code text)
LANGUAGE sql STABLE SECURITY INVOKER
SET search_path TO 'public'
AS $function$
  SELECT a.display_name, a.storage_path, a.target_type, a.target_code, a.duration_seconds, a.mime_type, a.activity_code
  FROM public.erp_app_assets a
  WHERE a.asset_type = 'intro_ad' AND a.display_name = 'إعلان البداية'
    AND (a.activity_code = p_activity_code OR a.activity_code IS NULL)
  ORDER BY CASE WHEN p_activity_code IS NOT NULL AND a.activity_code = p_activity_code THEN 0 ELSE 1 END,
           a.created_at DESC
  LIMIT 1;
$function$;
REVOKE ALL ON FUNCTION public.get_silsila_public_intro_ad(text) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.get_silsila_public_intro_ad(text) TO anon, authenticated;

DROP POLICY IF EXISTS silsila_public_ads_insert_admin ON storage.objects;
CREATE POLICY silsila_public_ads_insert_admin
ON storage.objects FOR INSERT TO authenticated
WITH CHECK (
  bucket_id = 'silsila-public-ads'
  AND (storage.foldername(name))[3] IN ('banner_ad','popup_ad','intro_ad')
  AND EXISTS (
    SELECT 1 FROM public.erp_managed_apps a
    WHERE a.id::text = (storage.foldername(name))[2]
      AND a.company_id::text = (storage.foldername(name))[1]
      AND a.app_key = 'silsila'
      AND public.erp_user_has_company_role(a.company_id, ARRAY['owner','admin']::text[])
  )
);

DROP POLICY IF EXISTS silsila_public_ads_delete_admin ON storage.objects;
CREATE POLICY silsila_public_ads_delete_admin
ON storage.objects FOR DELETE TO authenticated
USING (
  bucket_id = 'silsila-public-ads'
  AND (storage.foldername(name))[3] IN ('banner_ad','popup_ad','intro_ad')
  AND EXISTS (
    SELECT 1 FROM public.erp_managed_apps a
    WHERE a.id::text = (storage.foldername(name))[2]
      AND a.company_id::text = (storage.foldername(name))[1]
      AND a.app_key = 'silsila'
      AND public.erp_user_has_company_role(a.company_id, ARRAY['owner','admin']::text[])
  )
);
