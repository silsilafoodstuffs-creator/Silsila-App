-- Public read-only access is limited to the five named banner records.
-- The function runs as the caller; RLS below limits visible rows to banner assets.
grant select on public.erp_app_assets to anon, authenticated;

drop policy if exists erp_app_assets_public_banner_read on public.erp_app_assets;
create policy erp_app_assets_public_banner_read
on public.erp_app_assets
for select
to anon, authenticated
using (
  asset_type = 'banner_ad'
  and display_name in ('إعلان 1','إعلان 2','إعلان 3','إعلان 4','إعلان 5')
);

create or replace function public.get_silsila_public_ads()
returns table (display_name text, storage_path text)
language sql
stable
security invoker
set search_path = public
as $$
  with ranked_ads as (
    select
      assets.display_name,
      assets.storage_path,
      row_number() over (
        partition by assets.display_name
        order by assets.created_at desc
      ) as slot_rank
    from public.erp_app_assets assets
    where assets.asset_type = 'banner_ad'
      and assets.display_name in ('إعلان 1','إعلان 2','إعلان 3','إعلان 4','إعلان 5')
  )
  select ranked_ads.display_name, ranked_ads.storage_path
  from ranked_ads
  where ranked_ads.slot_rank = 1
  order by ranked_ads.display_name;
$$;

revoke all on function public.get_silsila_public_ads() from public;
grant execute on function public.get_silsila_public_ads() to anon, authenticated;
