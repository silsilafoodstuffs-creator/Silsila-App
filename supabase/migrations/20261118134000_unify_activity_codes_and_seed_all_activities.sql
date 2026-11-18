BEGIN;

-- Canonical activity identifiers are 01..20, matching erp_item_categories.activity_code.
-- Keep the shared app picker and ERP activity master aligned with that catalogue.
INSERT INTO public.activity_types
  (code, name, name_en, sort_order, is_active, show_in_app)
VALUES
  ('01','مواد غذائية','Foodstuffs',1,true,true),
  ('02','لوازم بناء','Building Supplies',2,true,true),
  ('03','ملابس واكسسوارات','Clothing & Accessories',3,true,true),
  ('04','أجهزة وإلكترونيات','Electronics',4,true,true),
  ('05','سيارات ومعدات','Vehicles & Equipment',5,true,true),
  ('06','خدمات شحن ونقل','Shipping & Transport Services',6,true,true),
  ('07','أثاث وديكورات','Furniture & Decor',7,true,true),
  ('08','أدوات كهربائية','Electrical Tools',8,true,true),
  ('09','مكتبات وقرطاسية','Stationery & Office Supplies',9,true,true),
  ('10','مستلزمات طبية','Medical Supplies',10,true,true),
  ('11','مستحضرات تجميل وعناية','Beauty & Personal Care',11,true,true),
  ('12','زراعة ومستلزمات زراعية','Agriculture Supplies',12,true,true),
  ('13','قطع غيار ومستلزمات صيانة','Spare Parts & Maintenance',13,true,true),
  ('14','مستلزمات فندقية ومطاعم','Hospitality & Restaurant Supplies',14,true,true),
  ('15','تعبئة وتغليف','Packaging Supplies',15,true,true),
  ('16','منظفات ومستلزمات نظافة','Cleaning Supplies',16,true,true),
  ('17','مستلزمات حيوانات وأعلاف','Pet Supplies & Feed',17,true,true),
  ('18','خدمات نقل وتوصيل','Transport & Delivery Services',18,true,true),
  ('19','أنشطة أخرى','Other Activities',19,true,true),
  ('20','كتب ومطبوعات','Books & Publications',20,true,true)
ON CONFLICT (code) DO UPDATE SET
  name = EXCLUDED.name,
  name_en = EXCLUDED.name_en,
  sort_order = EXCLUDED.sort_order,
  is_active = true,
  show_in_app = true;

-- Convert legacy ACT001..ACT007 ERP workspace rows to the same short codes.
-- Preserve record_data and stable row metadata.
UPDATE public.erp_workspace_records
SET record_key = lpad((substring(record_key from 4)::integer)::text, 2, '0'),
    record_data = jsonb_set(
      record_data,
      '{كود النشاط}',
      to_jsonb(lpad((substring(record_key from 4)::integer)::text, 2, '0')),
      true
    ),
    updated_at = now()
WHERE page_key = 'أنواع الأنشطة'
  AND record_key ~ '^ACT00[1-7]$'
  AND NOT EXISTS (
    SELECT 1
    FROM public.erp_workspace_records canonical
    WHERE canonical.company_id = erp_workspace_records.company_id
      AND canonical.page_key = erp_workspace_records.page_key
      AND canonical.record_key = lpad((substring(erp_workspace_records.record_key from 4)::integer)::text, 2, '0')
  );

-- Ensure each company with an activity master has all 20 rows; never overwrite
-- a company-specific name or other customized values already stored.
INSERT INTO public.erp_workspace_records
  (company_id, page_key, record_key, record_data, updated_at)
SELECT
  companies.company_id,
  'أنواع الأنشطة',
  activities.code,
  jsonb_build_object(
    'ترتيب السطر', activities.sort_order::text,
    'كود النشاط', activities.code,
    'اسم النشاط عربي', activities.name,
    'اسم النشاط إنجليزي', activities.name_en,
    'نشط', 'true',
    'يظهر في التطبيق', 'true',
    'صورة النشاط', ''
  ),
  now()
FROM (
  SELECT DISTINCT company_id
  FROM public.erp_workspace_records
  WHERE page_key = 'أنواع الأنشطة'
) companies
CROSS JOIN (
  VALUES
    ('01','مواد غذائية','Foodstuffs',1),
    ('02','لوازم بناء','Building Supplies',2),
    ('03','ملابس واكسسوارات','Clothing & Accessories',3),
    ('04','أجهزة وإلكترونيات','Electronics',4),
    ('05','سيارات ومعدات','Vehicles & Equipment',5),
    ('06','خدمات شحن ونقل','Shipping & Transport Services',6),
    ('07','أثاث وديكورات','Furniture & Decor',7),
    ('08','أدوات كهربائية','Electrical Tools',8),
    ('09','مكتبات وقرطاسية','Stationery & Office Supplies',9),
    ('10','مستلزمات طبية','Medical Supplies',10),
    ('11','مستحضرات تجميل وعناية','Beauty & Personal Care',11),
    ('12','زراعة ومستلزمات زراعية','Agriculture Supplies',12),
    ('13','قطع غيار ومستلزمات صيانة','Spare Parts & Maintenance',13),
    ('14','مستلزمات فندقية ومطاعم','Hospitality & Restaurant Supplies',14),
    ('15','تعبئة وتغليف','Packaging Supplies',15),
    ('16','منظفات ومستلزمات نظافة','Cleaning Supplies',16),
    ('17','مستلزمات حيوانات وأعلاف','Pet Supplies & Feed',17),
    ('18','خدمات نقل وتوصيل','Transport & Delivery Services',18),
    ('19','أنشطة أخرى','Other Activities',19),
    ('20','كتب ومطبوعات','Books & Publications',20)
) AS activities(code, name, name_en, sort_order)
ON CONFLICT (company_id, page_key, record_key) DO NOTHING;

COMMIT;
