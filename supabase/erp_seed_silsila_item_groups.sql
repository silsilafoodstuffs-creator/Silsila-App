-- Seed only the user-provided Silsila food-category names.
-- No products, supplier relationships, prices, balances or stock quantities are invented.
-- Safe to rerun: existing category codes are updated to the approved Arabic labels.

begin;

insert into public.erp_item_groups (company_id, group_code, group_name, is_active)
select c.id, seed.group_code, seed.group_name, true
from public.erp_companies c
cross join (
  values
    ('FOOD-GHEE', 'سمنات'),
    ('FOOD-OIL', 'زيوت'),
    ('FOOD-PASTA', 'مكرونات'),
    ('FOOD-LEGUMES', 'بقوليات'),
    ('FOOD-HOT-DRINKS', 'مشروبات ساخنة'),
    ('FOOD-SOFT-DRINKS', 'مشروبات غازية'),
    ('FOOD-CHEESE', 'جبن'),
    ('FOOD-DAIRY', 'ألبان'),
    ('FOOD-JUICE', 'عصائر'),
    ('FOOD-SNACKS', 'مقرمشات'),
    ('FOOD-CLEANING', 'منظفات'),
    ('FOOD-HARDWARE', 'خردوات'),
    ('FOOD-SUPPLEMENTS', 'مكملات طعام'),
    ('FOOD-SWEETS', 'حلويات'),
    ('FOOD-CANNED', 'معلبات'),
    ('FOOD-PAPER', 'ورقيات'),
    ('FOOD-BAKERY', 'مخبوزات'),
    ('FOOD-CHOCOLATE', 'شيكولاتة'),
    ('FOOD-OTHER', 'أصناف أخرى')
) as seed(group_code, group_name)
where c.is_active = true
  and (
    coalesce(c.trade_name, '') ilike '%سلسلة%'
    or coalesce(c.legal_name, '') ilike '%سلسلة%'
  )
on conflict (company_id, group_code)
do update set
  group_name = excluded.group_name,
  is_active = true;

commit;
