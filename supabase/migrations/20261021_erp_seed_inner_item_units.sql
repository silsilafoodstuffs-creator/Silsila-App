-- Add a selectable inner selling unit for seeded wholesale products.
-- conversion_factor means inner units per base pack, so the picker divides pack price by this factor.
insert into public.erp_item_units
  (company_id,item_id,unit_code,unit_name,conversion_factor,is_base_unit,is_active)
select
  i.company_id,
  i.id,
  'INNER',
  case
    when i.item_name ilike 'عصير%' and i.item_name ilike '%235 مللي%' then 'علبة 235 مللي'
    when i.item_name ilike 'عصير%' and i.item_name ilike '%1 لتر%' then 'علبة 1 لتر'
    when i.item_name ilike 'بسكويت%' then 'علبة بسكويت'
    when i.item_name ilike 'جبنة%' and i.item_name ilike '%ثمن كيلو%' then 'علبة جبنة ثمن كيلو'
    when i.item_name ilike 'جبنة%' and i.item_name ilike '%ربع كيلو%' then 'علبة جبنة ربع كيلو'
    when i.item_name ilike 'جبنة%' and i.item_name ilike '%نصف كيلو%' then 'علبة جبنة نصف كيلو'
    else 'وحدة داخلية'
  end,
  substring(i.base_unit from '\(([0-9]+)')::numeric,
  false,
  true
from public.erp_items i
where i.base_unit ~ '\([0-9]+'
on conflict (item_id,unit_code) do nothing;
