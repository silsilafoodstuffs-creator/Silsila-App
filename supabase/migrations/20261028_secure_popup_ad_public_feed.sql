-- Public ad reads stay scoped to five banners and one popup; both RPCs run as invoker.
GRANT SELECT ON public.erp_app_assets TO anon, authenticated;

DROP POLICY IF EXISTS erp_app_assets_public_banner_read ON public.erp_app_assets;
CREATE POLICY erp_app_assets_public_banner_read
ON public.erp_app_assets FOR SELECT TO anon, authenticated
USING (
  (asset_type = 'banner_ad' AND display_name IN ('إعلان 1','إعلان 2','إعلان 3','إعلان 4','إعلان 5'))
  OR (asset_type = 'popup_ad' AND display_name = 'إعلان منبثق')
);

ALTER FUNCTION public.get_silsila_public_popup_ads() SECURITY INVOKER;
REVOKE ALL ON FUNCTION public.get_silsila_public_popup_ads() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.get_silsila_public_popup_ads() TO anon, authenticated;
REVOKE ALL ON FUNCTION public.get_silsila_public_ads() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.get_silsila_public_ads() TO anon, authenticated;
