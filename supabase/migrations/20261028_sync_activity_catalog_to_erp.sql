BEGIN;
-- Keep the app catalog aligned with the seven activity records maintained in the ERP master screen.
UPDATE public.activity_types SET show_in_app = false;

UPDATE public.activity_types
SET name = '__silsila_activity_sync__' || id::text
WHERE code IN ('ACT001','ACT002','ACT003','ACT004','ACT005','ACT006','ACT007');

INSERT INTO public.activity_types (code, name, name_en, sort_order, is_active, show_in_app)
VALUES
  ('ACT001','مواد غذائية','Foodstuffs',1,true,true),
  ('ACT002','لوازم بناء','Building Supplies',2,true,true),
  ('ACT003','ملابس واكسسوارات','Clothing & Accessories',3,true,true),
  ('ACT004','أجهزة وإلكترونيات','Electronics',4,true,true),
  ('ACT005','سيارات ومعدات','Vehicles & Equipment',5,true,true),
  ('ACT006','خدمات شحن ونقل','Shipping & Transport Services',6,true,true),
  ('ACT007','أثاث وديكورات','Furniture & Decor',7,true,true)
ON CONFLICT (code) DO UPDATE SET
  name = EXCLUDED.name,
  name_en = EXCLUDED.name_en,
  sort_order = EXCLUDED.sort_order,
  is_active = EXCLUDED.is_active,
  show_in_app = EXCLUDED.show_in_app;
COMMIT;
