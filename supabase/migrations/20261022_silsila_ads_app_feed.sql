-- Limit the public banner feed to the managed Silsila app only.
CREATE OR REPLACE FUNCTION public.get_silsila_public_ads()
RETURNS TABLE(display_name text, storage_path text)
LANGUAGE sql
STABLE
SET search_path TO 'public'
AS $function$
  WITH ranked_ads AS (
    SELECT assets.display_name,
           assets.storage_path,
           row_number() OVER (
             PARTITION BY assets.display_name
             ORDER BY assets.created_at DESC
           ) AS slot_rank
    FROM public.erp_app_assets AS assets
    JOIN public.erp_managed_apps AS apps ON apps.id = assets.app_id
    WHERE apps.app_key = 'silsila'
      AND assets.asset_type = 'banner_ad'
      AND assets.display_name IN ('إعلان 1','إعلان 2','إعلان 3','إعلان 4','إعلان 5')
  )
  SELECT ranked_ads.display_name, ranked_ads.storage_path
  FROM ranked_ads
  WHERE ranked_ads.slot_rank = 1
  ORDER BY ranked_ads.display_name;
$function$;
GRANT EXECUTE ON FUNCTION public.get_silsila_public_ads() TO anon, authenticated;
