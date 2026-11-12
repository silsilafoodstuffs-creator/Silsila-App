
create or replace function public.get_offer_geo_customer_counts()
returns table(governorate text, district text, area text, customer_count bigint)
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
  ),
  geo as (
    select g.* from public.erp_geographic_data g
    join chosen_company c on c.company_id = g.company_id
    where g.is_active = true
  ),
  customers as (
    select p.governorate, p.district, p.area
    from public.profiles p
    where auth.uid() is not null
      and (lower(coalesce(p.account_type, '')) = 'customer'
        or lower(coalesce(p.role, '')) = 'customer')
      and p.account_status in ('approved','active','مفعل','معتمد')
      and nullif(btrim(p.governorate), '') is not null
  )
  select
    coalesce(gov.name_ar, nullif(btrim(c.governorate), '')) as governorate,
    coalesce(dist.name_ar, nullif(btrim(c.district), '')) as district,
    coalesce(area.name_ar, nullif(btrim(c.area), '')) as area,
    count(*)::bigint as customer_count
  from customers c
  left join geo gov
    on gov.level = 'governorate'
   and regexp_replace(lower(btrim(gov.name_ar)), '^(محافظة|مديرية)\s+', '') =
       regexp_replace(lower(btrim(c.governorate)), '^(محافظة|مديرية)\s+', '')
  left join geo dist
    on dist.level = 'district'
   and dist.parent_id = gov.id
   and regexp_replace(lower(btrim(dist.name_ar)), '^(مدينة|قسم|حي|مركز|بندر)\s+', '') =
       regexp_replace(lower(btrim(c.district)), '^(مدينة|قسم|حي|مركز|بندر)\s+', '')
  left join geo area
    on area.level = 'area'
   and area.parent_id = dist.id
   and regexp_replace(lower(btrim(area.name_ar)), '^(قرية|منطقة|شياخة|ناحية)\s+', '') =
       regexp_replace(lower(btrim(c.area)), '^(قرية|منطقة|شياخة|ناحية)\s+', '')
  group by 1,2,3;
$$;
