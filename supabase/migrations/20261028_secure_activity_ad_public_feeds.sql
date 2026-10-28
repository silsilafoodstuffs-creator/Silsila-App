-- Public RPCs expose only Silsila's published ad metadata. Direct anon table reads are unnecessary.
REVOKE SELECT ON public.erp_app_assets FROM anon;

DROP FUNCTION IF EXISTS public.get_silsila_public_ads(text);
CREATE OR REPLACE FUNCTION public.get_silsila_public_ads(p_activity_code text DEFAULT NULL)
RETURNS TABLE(display_name text, storage_path text, target_type text, target_code text, duration_seconds integer, mime_type text, activity_code text)
LANGUAGE sql STABLE SECURITY DEFINER
SET search_path TO 'public'
AS $function$
  WITH specific AS (
    SELECT a.storage_path, a.target_type, a.target_code, a.duration_seconds, a.mime_type,
           row_number() OVER (ORDER BY a.display_name) AS rn
    FROM public.erp_app_assets a
    JOIN public.erp_managed_apps app ON app.id = a.app_id AND app.app_key = 'silsila'
    WHERE a.asset_type = 'banner_ad' AND p_activity_code IS NOT NULL
      AND a.activity_code = p_activity_code
      AND a.display_name IN ('إعلان 1','إعلان 2','إعلان 3','إعلان 4','إعلان 5')
  ),
  global_ads AS (
    SELECT a.storage_path, a.target_type, a.target_code, a.duration_seconds, a.mime_type,
           row_number() OVER (ORDER BY a.display_name) AS rn
    FROM public.erp_app_assets a
    JOIN public.erp_managed_apps app ON app.id = a.app_id AND app.app_key = 'silsila'
    WHERE a.asset_type = 'banner_ad' AND a.activity_code IS NULL
      AND a.display_name IN ('إعلان 1','إعلان 2','إعلان 3','إعلان 4','إعلان 5')
  ),
  combined AS (
    SELECT s.storage_path, s.target_type, s.target_code, s.duration_seconds, s.mime_type, s.rn AS output_rank,
           p_activity_code AS activity_code FROM specific s
    UNION ALL
    SELECT g.storage_path, g.target_type, g.target_code, g.duration_seconds, g.mime_type,
           (SELECT count(*) FROM specific) + g.rn AS output_rank, NULL::text AS activity_code
    FROM global_ads g WHERE g.rn <= 5 - (SELECT count(*) FROM specific)
  )
  SELECT ('إعلان ' || output_rank::text), storage_path, target_type, target_code, duration_seconds, mime_type, activity_code
  FROM combined WHERE output_rank <= 5 ORDER BY output_rank;
$function$;
REVOKE ALL ON FUNCTION public.get_silsila_public_ads(text) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.get_silsila_public_ads(text) TO anon, authenticated;

CREATE OR REPLACE FUNCTION public.get_silsila_public_popup_ads(p_activity_code text DEFAULT NULL)
RETURNS TABLE(display_name text, storage_path text, target_type text, target_code text, duration_seconds integer, mime_type text, activity_code text)
LANGUAGE sql STABLE SECURITY DEFINER
SET search_path TO 'public'
AS $function$
  SELECT a.display_name, a.storage_path, a.target_type, a.target_code, a.duration_seconds, a.mime_type, a.activity_code
  FROM public.erp_app_assets a
  JOIN public.erp_managed_apps app ON app.id = a.app_id AND app.app_key = 'silsila'
  WHERE a.asset_type = 'popup_ad' AND a.display_name = 'إعلان منبثق'
    AND (a.activity_code = p_activity_code OR a.activity_code IS NULL)
  ORDER BY CASE WHEN p_activity_code IS NOT NULL AND a.activity_code = p_activity_code THEN 0 ELSE 1 END, a.created_at DESC
  LIMIT 1;
$function$;
REVOKE ALL ON FUNCTION public.get_silsila_public_popup_ads(text) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.get_silsila_public_popup_ads(text) TO anon, authenticated;

CREATE OR REPLACE FUNCTION public.get_silsila_public_intro_ad(p_activity_code text DEFAULT NULL)
RETURNS TABLE(display_name text, storage_path text, target_type text, target_code text, duration_seconds integer, mime_type text, activity_code text)
LANGUAGE sql STABLE SECURITY DEFINER
SET search_path TO 'public'
AS $function$
  SELECT a.display_name, a.storage_path, a.target_type, a.target_code, a.duration_seconds, a.mime_type, a.activity_code
  FROM public.erp_app_assets a
  JOIN public.erp_managed_apps app ON app.id = a.app_id AND app.app_key = 'silsila'
  WHERE a.asset_type = 'intro_ad' AND a.display_name = 'إعلان البداية'
    AND (a.activity_code = p_activity_code OR a.activity_code IS NULL)
  ORDER BY CASE WHEN p_activity_code IS NOT NULL AND a.activity_code = p_activity_code THEN 0 ELSE 1 END, a.created_at DESC
  LIMIT 1;
$function$;
REVOKE ALL ON FUNCTION public.get_silsila_public_intro_ad(text) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.get_silsila_public_intro_ad(text) TO anon, authenticated;
