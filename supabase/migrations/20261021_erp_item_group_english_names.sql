-- Fill missing English labels for the existing category hierarchy without overwriting populated translations.
with category_names(code,name_en) as (
  values
    ('FOOD-BISCUITS','Biscuits'),
    ('FOOD-CHEESE','Cheese'),
    ('FOOD-JUICES','Juices'),
    ('BISCUIT-LAMBADA','Lambada'),
    ('BISCUIT-WAFER','Wafer Biscuits'),
    ('CHEESE-RHODES','Rhodes Cheese'),
    ('CHEESE-TETRA','Tetra Pak Cheese'),
    ('FOOD-JUICES-TETRA','Tetra Pak Juices'),
    ('JUICE-BETTY','Betty'),
    ('JUICE-JUHAINA','Juhayna')
)
update public.erp_item_groups g
set group_name_en = n.name_en
from category_names n
where g.group_code = n.code
  and coalesce(btrim(g.group_name_en),'') = '';
