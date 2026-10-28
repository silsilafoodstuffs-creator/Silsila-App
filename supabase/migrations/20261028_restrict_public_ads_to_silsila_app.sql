-- Public ad metadata is exposed only for the Silsila managed app.
DROP POLICY IF EXISTS erp_app_assets_public_banner_read ON public.erp_app_assets;
CREATE POLICY erp_app_assets_public_banner_read
ON public.erp_app_assets FOR SELECT TO anon, authenticated
USING (
  (
    (asset_type = 'banner_ad' AND display_name IN ('إعلان 1','إعلان 2','إعلان 3','إعلان 4','إعلان 5'))
    OR (asset_type = 'popup_ad' AND display_name = 'إعلان منبثق')
    OR (asset_type = 'intro_ad' AND display_name = 'إعلان البداية')
  )
  AND EXISTS (
    SELECT 1 FROM public.erp_managed_apps app
    WHERE app.id = app_id AND app.app_key = 'silsila'
  )
);
