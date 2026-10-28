-- Popup ads and click-through destinations for the five header ads.
ALTER TABLE public.erp_app_assets
  ADD COLUMN IF NOT EXISTS target_type text NOT NULL DEFAULT 'none'
    CHECK (target_type IN ('none','category','supplier')),
  ADD COLUMN IF NOT EXISTS target_code text,
  ADD COLUMN IF NOT EXISTS duration_seconds integer NOT NULL DEFAULT 5
    CHECK (duration_seconds BETWEEN 1 AND 120);

ALTER TABLE public.erp_app_assets DROP CONSTRAINT IF EXISTS erp_app_assets_asset_type_check;
ALTER TABLE public.erp_app_assets ADD CONSTRAINT erp_app_assets_asset_type_check
  CHECK (asset_type IN (
    'app_logo','splash','app_icon','category','item','supplier',
    'customer','shipping_company','banner_ad','popup_ad','other'
  ));

CREATE INDEX IF NOT EXISTS erp_app_assets_public_ads_idx
  ON public.erp_app_assets(asset_type, display_name, created_at DESC)
  WHERE asset_type IN ('banner_ad','popup_ad');

CREATE OR REPLACE FUNCTION public.get_silsila_public_ads()
RETURNS TABLE(
  display_name text,
  storage_path text,
  target_type text,
  target_code text,
  duration_seconds integer
)
LANGUAGE sql STABLE SECURITY DEFINER
SET search_path TO 'public'
AS $function$
  WITH ranked_ads AS (
    SELECT assets.display_name, assets.storage_path,
           assets.target_type, assets.target_code, assets.duration_seconds,
           row_number() OVER (
             PARTITION BY assets.display_name ORDER BY assets.created_at DESC
           ) AS slot_rank
    FROM public.erp_app_assets AS assets
    WHERE assets.asset_type = 'banner_ad'
      AND assets.display_name IN ('إعلان 1','إعلان 2','إعلان 3','إعلان 4','إعلان 5')
  )
  SELECT display_name, storage_path, target_type, target_code, duration_seconds
  FROM ranked_ads WHERE slot_rank = 1
  ORDER BY display_name;
$function$;
GRANT EXECUTE ON FUNCTION public.get_silsila_public_ads() TO anon, authenticated;

CREATE OR REPLACE FUNCTION public.get_silsila_public_popup_ads()
RETURNS TABLE(
  display_name text,
  storage_path text,
  target_type text,
  target_code text,
  duration_seconds integer
)
LANGUAGE sql STABLE SECURITY DEFINER
SET search_path TO 'public'
AS $function$
  WITH ranked_ads AS (
    SELECT assets.display_name, assets.storage_path,
           assets.target_type, assets.target_code, assets.duration_seconds,
           row_number() OVER (
             PARTITION BY assets.display_name ORDER BY assets.created_at DESC
           ) AS slot_rank
    FROM public.erp_app_assets AS assets
    WHERE assets.asset_type = 'popup_ad'
      AND assets.display_name = 'إعلان منبثق'
  )
  SELECT display_name, storage_path, target_type, target_code, duration_seconds
  FROM ranked_ads WHERE slot_rank = 1;
$function$;
GRANT EXECUTE ON FUNCTION public.get_silsila_public_popup_ads() TO anon, authenticated;
