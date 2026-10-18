-- Allow company owners/admins to edit registered app asset metadata.
-- Apply after erp_app_management_schema.sql and erp_security_membership.sql.
begin;

drop policy if exists erp_app_assets_update_admin on public.erp_app_assets;
create policy erp_app_assets_update_admin on public.erp_app_assets
for update to authenticated
using (
  exists (
    select 1 from public.erp_managed_apps a
    where a.id = app_id
      and public.erp_user_has_company_role(a.company_id, array['owner','admin']::text[])
  )
)
with check (
  (uploaded_by is null or uploaded_by = auth.uid())
  and exists (
    select 1 from public.erp_managed_apps a
    where a.id = app_id
      and public.erp_user_has_company_role(a.company_id, array['owner','admin']::text[])
  )
);

grant update on public.erp_app_assets to authenticated;
commit;
