-- Complete the missing fresh-food departments in the Egyptian wholesale food catalogue.
-- Category structure follows common Egyptian grocery taxonomy, including Amazon Now's
-- fresh produce, meat/seafood, and ready-to-eat departments. Photos are imported separately
-- from reusable, attributed Wikimedia Commons sources by the category-image workflow.
DO $$
DECLARE
  v_company uuid := '47278c99-7743-4dd4-9ce6-d11f28e02504';
BEGIN
  -- Main departments
  INSERT INTO public.erp_item_categories
    (company_id, activity_code, category_code, category_name, category_name_en,
     parent_id, is_active, show_in_app)
  VALUES
    (v_company, 'ACT001', 'Cat89', 'خضروات وفاكهة طازجة', 'Fresh Fruit & Vegetables', NULL, true, true),
    (v_company, 'ACT001', 'Cat90', 'لحوم ودواجن وأسماك', 'Meat, Poultry & Seafood', NULL, true, true),
    (v_company, 'ACT001', 'Cat91', 'أطعمة جاهزة ومأكولات طازجة', 'Deli & Ready-to-Eat Foods', NULL, true, true)
  ON CONFLICT (company_id, activity_code, category_code) WHERE activity_code IS NOT NULL
  DO UPDATE SET category_name = EXCLUDED.category_name,
                category_name_en = EXCLUDED.category_name_en,
                is_active = true, show_in_app = true;

  -- Second level
  INSERT INTO public.erp_item_categories
    (company_id, activity_code, category_code, category_name, category_name_en,
     parent_id, is_active, show_in_app)
  SELECT v_company, 'ACT001', x.code, x.name, x.name_en, p.id, true, true
  FROM (VALUES
    ('Cat8901','خضروات طازجة','Fresh Vegetables','Cat89'),
    ('Cat8902','فاكهة طازجة','Fresh Fruits','Cat89'),
    ('Cat8903','أعشاب وخضروات ورقية','Fresh Herbs & Leafy Greens','Cat89'),
    ('Cat9001','لحوم طازجة','Fresh Meat','Cat90'),
    ('Cat9002','دواجن طازجة','Fresh Poultry','Cat90'),
    ('Cat9003','أسماك ومأكولات بحرية','Fish & Seafood','Cat90'),
    ('Cat9101','وجبات جاهزة','Ready Meals','Cat91'),
    ('Cat9102','مأكولات مطهية','Cooked & Prepared Foods','Cat91'),
    ('Cat9103','سلطات ومقبلات','Salads & Appetizers','Cat91')
  ) AS x(code,name,name_en,parent_code)
  JOIN public.erp_item_categories p
    ON p.company_id = v_company AND p.activity_code = 'ACT001'
   AND p.category_code = x.parent_code
  ON CONFLICT (company_id, activity_code, category_code) WHERE activity_code IS NOT NULL
  DO UPDATE SET category_name = EXCLUDED.category_name,
                category_name_en = EXCLUDED.category_name_en,
                parent_id = EXCLUDED.parent_id,
                is_active = true, show_in_app = true;

  -- Third level
  INSERT INTO public.erp_item_categories
    (company_id, activity_code, category_code, category_name, category_name_en,
     parent_id, is_active, show_in_app)
  SELECT v_company, 'ACT001', x.code, x.name, x.name_en, p.id, true, true
  FROM (VALUES
    ('Cat890101','خضروات ورقية','Leafy Vegetables','Cat8901'),
    ('Cat890102','خضروات جذرية وثمرية','Root & Fruiting Vegetables','Cat8901'),
    ('Cat890201','موالح وفواكه موسمية','Citrus & Seasonal Fruits','Cat8902'),
    ('Cat890202','فواكه استوائية ومحلية','Tropical & Local Fruits','Cat8902'),
    ('Cat890301','أعشاب طازجة','Fresh Herbs','Cat8903'),
    ('Cat890302','ورقيات مشكلة','Mixed Leafy Greens','Cat8903'),
    ('Cat900101','لحوم حمراء','Red Meat','Cat9001'),
    ('Cat900102','لحوم مفرومة ومجهزة','Minced & Prepared Meat','Cat9001'),
    ('Cat900201','دواجن كاملة','Whole Poultry','Cat9002'),
    ('Cat900202','قطع دواجن','Poultry Cuts','Cat9002'),
    ('Cat900301','أسماك طازجة','Fresh Fish','Cat9003'),
    ('Cat900302','جمبري ومأكولات بحرية','Shrimp & Seafood','Cat9003'),
    ('Cat910101','وجبات مبردة جاهزة','Chilled Ready Meals','Cat9101'),
    ('Cat910102','وجبات سريعة التحضير','Quick-Prep Meals','Cat9101'),
    ('Cat910201','أطعمة مطهية','Cooked Foods','Cat9102'),
    ('Cat910202','مقبلات ومخبوزات مالحة','Savory Deli & Bakery','Cat9102'),
    ('Cat910301','سلطات طازجة','Fresh Salads','Cat9103'),
    ('Cat910302','مقبلات باردة','Cold Appetizers','Cat9103')
  ) AS x(code,name,name_en,parent_code)
  JOIN public.erp_item_categories p
    ON p.company_id = v_company AND p.activity_code = 'ACT001'
   AND p.category_code = x.parent_code
  ON CONFLICT (company_id, activity_code, category_code) WHERE activity_code IS NOT NULL
  DO UPDATE SET category_name = EXCLUDED.category_name,
                category_name_en = EXCLUDED.category_name_en,
                parent_id = EXCLUDED.parent_id,
                is_active = true, show_in_app = true;
END $$;
