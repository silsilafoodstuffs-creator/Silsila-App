-- Standardize legacy salary element and item unit catalog codes.
-- Keep the protected stocktake shortage element code unchanged because database
-- triggers and settlement links intentionally address SYSSTOCKSHORTAGE.

with existing as (
  select company_id,
         coalesce(max(substring(element_code from 4)::bigint), 0) as max_code
  from public.erp_hr_salary_elements
  where element_code ~ '^SAL[0-9]{4,}$'
  group by company_id
), legacy as (
  select e.id, e.company_id,
         row_number() over (partition by e.company_id order by e.element_code, e.id) as seq,
         coalesce(x.max_code, 0) as max_code
  from public.erp_hr_salary_elements e
  left join existing x on x.company_id = e.company_id
  where coalesce(e.is_system_locked, false) = false
    and e.element_code !~ '^SAL[0-9]{4,}$'
)
update public.erp_hr_salary_elements e
set element_code = 'SAL' || lpad((legacy.max_code + legacy.seq)::text, 4, '0'),
    updated_at = now()
from legacy
where e.id = legacy.id;

with existing as (
  select company_id, activity_code,
         coalesce(max(substring(unit_code from 4)::bigint), 0) as max_code
  from public.erp_item_unit_catalog
  where unit_code ~ '^UNT[0-9]{4,}$'
  group by company_id, activity_code
), legacy as (
  select u.id, u.company_id, u.activity_code,
         row_number() over (
           partition by u.company_id, u.activity_code
           order by u.unit_code, u.id
         ) as seq,
         coalesce(x.max_code, 0) as max_code
  from public.erp_item_unit_catalog u
  left join existing x
    on x.company_id = u.company_id and x.activity_code = u.activity_code
  where u.unit_code !~ '^UNT[0-9]{4,}$'
)
update public.erp_item_unit_catalog u
set unit_code = 'UNT' || lpad((legacy.max_code + legacy.seq)::text, 4, '0'),
    updated_at = now()
from legacy
where u.id = legacy.id;
