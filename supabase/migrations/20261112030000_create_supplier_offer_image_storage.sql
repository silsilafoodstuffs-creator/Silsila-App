insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values ('supplier-offers','supplier-offers',true,5242880,array['image/jpeg','image/png','image/webp'])
on conflict (id) do update set public=true, file_size_limit=5242880, allowed_mime_types=array['image/jpeg','image/png','image/webp'];

drop policy if exists "supplier offer images public read" on storage.objects;
create policy "supplier offer images public read" on storage.objects for select to public using (bucket_id='supplier-offers');
drop policy if exists "supplier offer images owner insert" on storage.objects;
create policy "supplier offer images owner insert" on storage.objects for insert to authenticated
with check (bucket_id='supplier-offers' and (storage.foldername(name))[1]=(select auth.uid())::text);
drop policy if exists "supplier offer images owner update" on storage.objects;
create policy "supplier offer images owner update" on storage.objects for update to authenticated
using (bucket_id='supplier-offers' and (storage.foldername(name))[1]=(select auth.uid())::text)
with check (bucket_id='supplier-offers' and (storage.foldername(name))[1]=(select auth.uid())::text);
drop policy if exists "supplier offer images owner delete" on storage.objects;
create policy "supplier offer images owner delete" on storage.objects for delete to authenticated
using (bucket_id='supplier-offers' and (storage.foldername(name))[1]=(select auth.uid())::text);
