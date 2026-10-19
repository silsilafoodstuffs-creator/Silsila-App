-- Public read access is intentional for the five marketing banners shown to all app users.
-- Upload and delete remain restricted to company owners/admins for the registered Silsila app.
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values (
  'silsila-public-ads',
  'silsila-public-ads',
  true,
  8388608,
  array['image/jpeg','image/png','image/webp','image/gif']
)
on conflict (id) do update set
  public = excluded.public,
  file_size_limit = excluded.file_size_limit,
  allowed_mime_types = excluded.allowed_mime_types;

drop policy if exists silsila_public_ads_insert_admin on storage.objects;
create policy silsila_public_ads_insert_admin
on storage.objects
for insert
to authenticated
with check (
  bucket_id = 'silsila-public-ads'
  and (storage.foldername(name))[3] = 'banner_ad'
  and exists (
    select 1
    from public.erp_managed_apps a
    where a.id::text = (storage.foldername(name))[2]
      and a.company_id::text = (storage.foldername(name))[1]
      and a.app_key = 'silsila'
      and public.erp_user_has_company_role(a.company_id, array['owner','admin']::text[])
  )
);

drop policy if exists silsila_public_ads_delete_admin on storage.objects;
create policy silsila_public_ads_delete_admin
on storage.objects
for delete
to authenticated
using (
  bucket_id = 'silsila-public-ads'
  and (storage.foldername(name))[3] = 'banner_ad'
  and exists (
    select 1
    from public.erp_managed_apps a
    where a.id::text = (storage.foldername(name))[2]
      and a.company_id::text = (storage.foldername(name))[1]
      and a.app_key = 'silsila'
      and public.erp_user_has_company_role(a.company_id, array['owner','admin']::text[])
  )
);
