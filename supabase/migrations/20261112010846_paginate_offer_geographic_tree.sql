
drop function if exists public.get_offer_geo_tree();
create function public.get_offer_geo_tree(
  p_offset integer default 0,
  p_limit integer default 1000
)
returns table(id uuid, parent_id uuid, name_ar text, level text, admin_type text)
language sql
stable
security definer
set search_path = public
as $$
  with chosen_company as (
    select company_id
    from public.erp_geographic_data
    where is_active = true
    group by company_id
    order by count(*) desc
    limit 1
  )
  select g.id, g.parent_id, g.name_ar, g.level, g.admin_type
  from public.erp_geographic_data g
  join chosen_company c on c.company_id = g.company_id
  where g.is_active = true
  order by case g.level when 'governorate' then 1 when 'district' then 2 else 3 end, g.name_ar, g.id
  limit greatest(1, least(coalesce(p_limit, 1000), 1000))
  offset greatest(coalesce(p_offset, 0), 0);
$$;
revoke all on function public.get_offer_geo_tree(integer, integer) from public;
grant execute on function public.get_offer_geo_tree(integer, integer) to authenticated;
