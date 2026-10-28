-- Metadata edits for ads must be tenant-scoped to company owners/admins.
GRANT UPDATE ON public.erp_app_assets TO authenticated;
DROP POLICY IF EXISTS erp_app_assets_update_admin ON public.erp_app_assets;
CREATE POLICY erp_app_assets_update_admin
ON public.erp_app_assets FOR UPDATE TO authenticated
USING (
  EXISTS (
    SELECT 1 FROM public.erp_managed_apps a
    WHERE a.id = app_id
      AND public.erp_user_has_company_role(a.company_id, ARRAY['owner','admin']::text[])
  )
)
WITH CHECK (
  EXISTS (
    SELECT 1 FROM public.erp_managed_apps a
    WHERE a.id = app_id
      AND public.erp_user_has_company_role(a.company_id, ARRAY['owner','admin']::text[])
  )
);
