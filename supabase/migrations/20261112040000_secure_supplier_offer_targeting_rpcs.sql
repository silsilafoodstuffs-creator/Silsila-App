create or replace function public.get_offer_geo_tree(
  p_offset integer default 0,
  p_limit integer default 1000
)
returns table(id uuid, parent_id uuid, name_ar text, level text, admin_type text)
language sql
stable
security definer
set search_path = public, pg_temp
as $function$
  with app_company as (
    select a.company_id from public.erp_managed_apps a
    where a.app_key = 'silsila' and a.status = 'active'
    order by a.created_at limit 1
  )
  select g.id, g.parent_id, g.name_ar, g.level, g.admin_type
  from public.erp_geographic_data g
  join app_company c on c.company_id = g.company_id
  where g.is_active = true
    and auth.uid() is not null
    and exists (
      select 1 from public.profiles p
      where p.id = auth.uid() and p.role = 'supplier'
        and p.account_status in ('approved','active','مفعل','معتمد')
    )
  order by case g.level when 'governorate' then 1 when 'district' then 2 else 3 end, g.name_ar, g.id
  limit greatest(1, least(coalesce(p_limit, 1000), 1000))
  offset greatest(coalesce(p_offset, 0), 0);
$function$;

create or replace function public.get_offer_geo_customer_counts()
returns table(governorate text, district text, area text, customer_count bigint)
language sql
stable
security definer
set search_path = public, pg_temp
as $function$
  with app_company as (
    select a.company_id from public.erp_managed_apps a
    where a.app_key = 'silsila' and a.status = 'active'
    order by a.created_at limit 1
  ),
  geo as (
    select g.* from public.erp_geographic_data g
    join app_company c on c.company_id = g.company_id
    where g.is_active = true
  ),
  customers as (
    select nullif(btrim(p.governorate), '') as governorate,
           nullif(btrim(p.district), '') as district,
           nullif(btrim(p.area), '') as area
    from public.profiles p
    where auth.uid() is not null
      and exists (
        select 1 from public.profiles supplier
        where supplier.id = auth.uid() and supplier.role = 'supplier'
          and supplier.account_status in ('approved','active','مفعل','معتمد')
      )
      and (lower(coalesce(p.account_type, '')) = 'customer' or lower(coalesce(p.role, '')) = 'customer')
      and p.account_status in ('approved','active','مفعل','معتمد')
      and nullif(btrim(p.governorate), '') is not null
  )
  select coalesce(gov.name_ar, c.governorate),
         coalesce(dist.name_ar, c.district),
         coalesce(area.name_ar, c.area),
         count(*)::bigint
  from customers c
  left join geo gov on gov.level = 'governorate'
    and regexp_replace(lower(btrim(gov.name_ar)), '^(محافظة|مديرية)[[:space:]]+', '') =
        regexp_replace(lower(btrim(c.governorate)), '^(محافظة|مديرية)[[:space:]]+', '')
  left join geo dist on dist.level = 'district' and dist.parent_id = gov.id
    and regexp_replace(lower(btrim(dist.name_ar)), '^(مدينة|قسم|حي|مركز|بندر)[[:space:]]+', '') =
        regexp_replace(lower(btrim(c.district)), '^(مدينة|قسم|حي|مركز|بندر)[[:space:]]+', '')
  left join geo area on area.level = 'area' and area.parent_id = dist.id
    and regexp_replace(lower(btrim(area.name_ar)), '^(قرية|منطقة|شياخة|ناحية)[[:space:]]+', '') =
        regexp_replace(lower(btrim(c.area)), '^(قرية|منطقة|شياخة|ناحية)[[:space:]]+', '')
  group by 1,2,3;
$function$;

create or replace function public.get_activity_customer_categories(p_activity_type text)
returns table(customer_category text, activity_name text)
language sql
stable
security definer
set search_path = public, pg_temp
as $function$
  select distinct c.customer_category, c.activity_name
  from public.erp_activity_customer_categories c
  join public.erp_business_workspaces w
    on w.id = c.workspace_id and w.platform_company_id = c.company_id
   and w.account_kind = 'supplier' and w.is_active = true
  join public.erp_managed_apps a
    on a.company_id = c.company_id and a.app_key = 'silsila' and a.status = 'active'
  where c.is_active = true
    and c.activity_type = nullif(btrim(p_activity_type), '')
    and auth.uid() is not null
    and exists (
      select 1 from public.profiles p
      where p.id = auth.uid() and p.role = 'supplier'
        and p.account_status in ('approved','active','مفعل','معتمد')
    )
  order by c.activity_name, c.customer_category;
$function$;

revoke all on function public.get_offer_geo_tree(integer, integer) from public, anon, authenticated;
revoke all on function public.get_offer_geo_customer_counts() from public, anon, authenticated;
revoke all on function public.get_activity_customer_categories(text) from public, anon, authenticated;
grant execute on function public.get_offer_geo_tree(integer, integer) to authenticated;
grant execute on function public.get_offer_geo_customer_counts() to authenticated;
grant execute on function public.get_activity_customer_categories(text) to authenticated;
