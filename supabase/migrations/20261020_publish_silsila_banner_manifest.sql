-- Public, read-only endpoint for the active Silsila marketing carousel.
-- Only the five known banner slot names and public image paths are returned.
create or replace function public.get_silsila_public_ads()
returns table (display_name text, storage_path text)
language sql
stable
security definer
set search_path = public
as $$
  with selected_app as (
    select a.id
    from public.erp_managed_apps a
    where a.app_key = 'silsila'
    order by a.updated_at desc nulls last, a.created_at desc
    limit 1
  ),
  ranked_ads as (
    select
      assets.display_name,
      assets.storage_path,
      row_number() over (
        partition by assets.display_name
        order by assets.created_at desc
      ) as slot_rank
    from public.erp_app_assets assets
    join selected_app app on app.id = assets.app_id
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
