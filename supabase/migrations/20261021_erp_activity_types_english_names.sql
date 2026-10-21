-- Fill the missing English labels for the seven seeded activity types without overwriting user edits.
with activity_names(code,name_en) as (
  values
    ('ACT001','Foodstuffs'),
    ('ACT002','Building Supplies'),
    ('ACT003','Clothing & Accessories'),
    ('ACT004','Electronics'),
    ('ACT005','Vehicles & Equipment'),
    ('ACT006','Shipping & Transport Services'),
    ('ACT007','Furniture & Decor')
)
update public.erp_workspace_records r
set record_data = jsonb_set(r.record_data, array['اسم النشاط إنجليزي'], to_jsonb(n.name_en), true),
    updated_at = now()
from activity_names n
where r.page_key = 'أنواع الأنشطة'
  and r.record_data->>'كود النشاط' = n.code
  and coalesce(r.record_data->>'اسم النشاط إنجليزي','') = '';
