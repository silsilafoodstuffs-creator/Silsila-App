-- Silsila ERP managed-app image storage.
-- Apply after erp_security_membership.sql and erp_app_management_schema.sql.
-- Private bucket; object paths are company_uuid/app_uuid/asset_type/file_name.
begin;

insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values (
  'erp-app-assets',
  'erp-app-assets',
  false,
  8388608,
  array['image/jpeg','image/png','image/webp','image/gif']
)
on conflict (id) do update
set public = false,
    file_size_limit = excluded.file_size_limit,
    allowed_mime_types = excluded.allowed_mime_types;

drop policy if exists erp_app_asset_objects_select_member on storage.objects;
create policy erp_app_asset_objects_select_member
on storage.objects for select to authenticated
using (
  bucket_id = 'erp-app-assets'
  and exists (
    select 1
    from public.erp_managed_apps a
    where a.id::text = (storage.foldername(name))[2]
      and a.company_id::text = (storage.foldername(name))[1]
      and public.erp_user_can_access_company(a.company_id)
  )
);

drop policy if exists erp_app_asset_objects_insert_admin on storage.objects;
create policy erp_app_asset_objects_insert_admin
on storage.objects for insert to authenticated
with check (
  bucket_id = 'erp-app-assets'
  and exists (
    select 1
    from public.erp_managed_apps a
    where a.id::text = (storage.foldername(name))[2]
      and a.company_id::text = (storage.foldername(name))[1]
      and public.erp_user_has_company_role(a.company_id, array['owner','admin']::text[])
  )
);

drop policy if exists erp_app_asset_objects_update_admin on storage.objects;
create policy erp_app_asset_objects_update_admin
on storage.objects for update to authenticated
using (
  bucket_id = 'erp-app-assets'
  and exists (
    select 1
    from public.erp_managed_apps a
    where a.id::text = (storage.foldername(name))[2]
      and a.company_id::text = (storage.foldername(name))[1]
      and public.erp_user_has_company_role(a.company_id, array['owner','admin']::text[])
  )
)
with check (
  bucket_id = 'erp-app-assets'
  and exists (
    select 1
    from public.erp_managed_apps a
    where a.id::text = (storage.foldername(name))[2]
      and a.company_id::text = (storage.foldername(name))[1]
      and public.erp_user_has_company_role(a.company_id, array['owner','admin']::text[])
  )
);

drop policy if exists erp_app_asset_objects_delete_admin on storage.objects;
create policy erp_app_asset_objects_delete_admin
on storage.objects for delete to authenticated
using (
  bucket_id = 'erp-app-assets'
  and exists (
    select 1
    from public.erp_managed_apps a
    where a.id::text = (storage.foldername(name))[2]
      and a.company_id::text = (storage.foldername(name))[1]
      and public.erp_user_has_company_role(a.company_id, array['owner','admin']::text[])
  )
);

commit;
