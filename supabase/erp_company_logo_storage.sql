-- Private, company-scoped storage for the legal/branding image on ERP company profiles.
begin;

insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values (
  'erp-company-assets',
  'erp-company-assets',
  false,
  8388608,
  array['image/jpeg','image/png','image/webp','image/gif']
)
on conflict (id) do update
set public = false,
    file_size_limit = excluded.file_size_limit,
    allowed_mime_types = excluded.allowed_mime_types;

drop policy if exists erp_company_logo_select_member on storage.objects;
create policy erp_company_logo_select_member
on storage.objects for select to authenticated
using (
  bucket_id = 'erp-company-assets'
  and exists (
    select 1 from public.erp_companies c
    where c.id::text = (storage.foldername(name))[1]
      and public.erp_user_can_access_company(c.id)
  )
);

drop policy if exists erp_company_logo_insert_admin on storage.objects;
create policy erp_company_logo_insert_admin
on storage.objects for insert to authenticated
with check (
  bucket_id = 'erp-company-assets'
  and exists (
    select 1 from public.erp_companies c
    where c.id::text = (storage.foldername(name))[1]
      and public.erp_user_has_company_role(c.id, array['owner','admin']::text[])
  )
);

drop policy if exists erp_company_logo_update_admin on storage.objects;
create policy erp_company_logo_update_admin
on storage.objects for update to authenticated
using (
  bucket_id = 'erp-company-assets'
  and exists (
    select 1 from public.erp_companies c
    where c.id::text = (storage.foldername(name))[1]
      and public.erp_user_has_company_role(c.id, array['owner','admin']::text[])
  )
)
with check (
  bucket_id = 'erp-company-assets'
  and exists (
    select 1 from public.erp_companies c
    where c.id::text = (storage.foldername(name))[1]
      and public.erp_user_has_company_role(c.id, array['owner','admin']::text[])
  )
);

drop policy if exists erp_company_logo_delete_admin on storage.objects;
create policy erp_company_logo_delete_admin
on storage.objects for delete to authenticated
using (
  bucket_id = 'erp-company-assets'
  and exists (
    select 1 from public.erp_companies c
    where c.id::text = (storage.foldername(name))[1]
      and public.erp_user_has_company_role(c.id, array['owner','admin']::text[])
  )
);

commit;
