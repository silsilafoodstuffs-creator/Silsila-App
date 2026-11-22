BEGIN;

-- Merge the eight disabled activity types into the twelve retained activities.
-- Preserve every item-category row, UUID, parent link, category code, image and item assignment.
DO $$
DECLARE v_total integer; v_inactive integer; v_categories integer; v_inactive_categories integer;
BEGIN
  SELECT count(*) INTO v_total FROM public.activity_types
  WHERE code ~ '^ACT(00[1-9]|01[0-9]|020)$';
  SELECT count(*) INTO v_inactive FROM public.activity_types
  WHERE code IN ('ACT008','ACT009','ACT011','ACT013','ACT014','ACT015','ACT016','ACT018')
    AND (is_active = false OR show_in_app = false);
  SELECT count(*) INTO v_categories FROM public.erp_item_categories;
  SELECT count(*) INTO v_inactive_categories FROM public.erp_item_categories
  WHERE activity_code IN ('08','09','11','13','14','15','16','18');
  IF v_total <> 20 OR v_inactive <> 8 OR v_categories <> 1170 OR v_inactive_categories <> 455 THEN
    RAISE EXCEPTION 'Precondition mismatch: activities %, inactive %, categories %, inactive-category rows %',
      v_total, v_inactive, v_categories, v_inactive_categories;
  END IF;
END $$;

CREATE TEMP TABLE _activity_master_recode (
  old_code text PRIMARY KEY, new_code text NOT NULL, new_order integer, keep_row boolean NOT NULL
) ON COMMIT DROP;

INSERT INTO _activity_master_recode VALUES
 ('ACT001','ACT001',1,true),('ACT002','ACT002',2,true),('ACT003','ACT003',3,true),
 ('ACT004','ACT004',4,true),('ACT005','ACT005',5,true),('ACT006','ACT006',6,true),
 ('ACT007','ACT007',7,true),('ACT008','ACT004',null,false),('ACT009','ACT012',null,false),
 ('ACT010','ACT008',8,true),('ACT011','ACT011',null,false),('ACT012','ACT009',9,true),
 ('ACT013','ACT005',null,false),('ACT014','ACT007',null,false),('ACT015','ACT001',null,false),
 ('ACT016','ACT011',null,false),('ACT017','ACT010',10,true),('ACT018','ACT006',null,false),
 ('ACT019','ACT011',11,true),('ACT020','ACT012',12,true);

-- Keep a recovery copy of the removed company-level rows outside the active page.
INSERT INTO public.erp_workspace_records
 (company_id,page_key,record_key,record_data,created_by,updated_by,created_at,updated_at)
SELECT company_id,'أرشيف أنواع الأنشطة 20261123',record_key,record_data,
       created_by,updated_by,created_at,now()
FROM public.erp_workspace_records
WHERE page_key='أنواع الأنشطة'
  AND record_key IN ('ACT008','ACT009','ACT011','ACT013','ACT014','ACT015','ACT016','ACT018')
ON CONFLICT (company_id,page_key,record_key) DO NOTHING;

-- The one duplicate label is qualified, not deleted.
UPDATE public.erp_item_categories
SET category_name='منظفات منزلية (مستلزمات تنظيف)'
WHERE category_code='1605' AND activity_code='16' AND category_name='منظفات منزلية';

-- Compute the final activity for every category, then update parents before children
-- because the database protects same-activity category hierarchies.
CREATE TEMP TABLE _activity_category_recode ON COMMIT DROP AS
WITH RECURSIVE category_tree AS (
  SELECT id,parent_id,0::integer AS depth
  FROM public.erp_item_categories WHERE parent_id IS NULL
  UNION ALL
  SELECT c.id,c.parent_id,p.depth+1
  FROM public.erp_item_categories c JOIN category_tree p ON p.id=c.parent_id
)
SELECT c.id,t.depth,
  CASE c.activity_code
    WHEN '01' THEN '01' WHEN '02' THEN '02' WHEN '03' THEN '03' WHEN '04' THEN '04'
    WHEN '05' THEN '05' WHEN '06' THEN '06' WHEN '07' THEN '07' WHEN '08' THEN '04'
    WHEN '09' THEN '12' WHEN '10' THEN '08' WHEN '11' THEN '11' WHEN '12' THEN '09'
    WHEN '13' THEN '05' WHEN '14' THEN '07' WHEN '15' THEN '01' WHEN '16' THEN '11'
    WHEN '17' THEN '10' WHEN '18' THEN '06' WHEN '19' THEN '11' WHEN '20' THEN '12'
    ELSE c.activity_code END AS target_activity_code
FROM public.erp_item_categories c JOIN category_tree t ON t.id=c.id;

DO $$
DECLARE v_mapped integer; v_max_depth integer; v_depth integer;
BEGIN
  SELECT count(*),max(depth) INTO v_mapped,v_max_depth FROM _activity_category_recode;
  IF v_mapped <> 1170 THEN
    RAISE EXCEPTION 'Category hierarchy map incomplete: mapped % of 1170 rows',v_mapped;
  END IF;
  FOR v_depth IN 0..v_max_depth LOOP
    UPDATE public.erp_item_categories c
    SET activity_code=m.target_activity_code
    FROM _activity_category_recode m
    WHERE c.id=m.id AND m.depth=v_depth
      AND c.activity_code IS DISTINCT FROM m.target_activity_code;
  END LOOP;
END $$;

-- Park all master codes temporarily to avoid unique-key collisions; FK updates cascade.
UPDATE public.activity_types a SET code='__REMOVED_'||a.code
FROM _activity_master_recode m WHERE a.code=m.old_code AND NOT m.keep_row;
UPDATE public.activity_types a SET code='__KEEP_'||a.code
FROM _activity_master_recode m WHERE a.code=m.old_code AND m.keep_row;
UPDATE public.activity_types a
SET code=m.new_code,sort_order=m.new_order,is_active=true,show_in_app=true
FROM _activity_master_recode m
WHERE a.code='__KEEP_'||m.old_code AND m.keep_row;

-- Move any brand references from removed codes to their retained activities.
UPDATE public.erp_brand_groups b SET activity_code=m.new_code
FROM _activity_master_recode m
WHERE b.activity_code='__REMOVED_'||m.old_code AND NOT m.keep_row;
UPDATE public.erp_brands b SET activity_code=m.new_code
FROM _activity_master_recode m
WHERE b.activity_code='__REMOVED_'||m.old_code AND NOT m.keep_row;

-- Synchronize other code-bearing ERP/app tables.
UPDATE public.erp_app_assets x SET activity_code=m.new_code FROM _activity_master_recode m WHERE x.activity_code=m.old_code;
UPDATE public.erp_app_ticker_ads x SET activity_code=m.new_code FROM _activity_master_recode m WHERE x.activity_code=m.old_code;
UPDATE public.erp_crm_activities x SET activity_code=m.new_code FROM _activity_master_recode m WHERE x.activity_code=m.old_code;
UPDATE public.erp_einvoice_settings x SET activity_code=m.new_code FROM _activity_master_recode m WHERE x.activity_code=m.old_code;
UPDATE public.erp_item_unit_catalog x SET activity_code=m.new_code FROM _activity_master_recode m WHERE x.activity_code=m.old_code;

-- Remove the disabled rows from the active company master and compact retained row keys.
DELETE FROM public.erp_workspace_records
WHERE page_key='أنواع الأنشطة'
  AND record_key IN ('ACT008','ACT009','ACT011','ACT013','ACT014','ACT015','ACT016','ACT018');

UPDATE public.erp_workspace_records
SET record_key='__TMP_'||record_key
WHERE page_key='أنواع الأنشطة'
  AND record_key IN ('ACT001','ACT002','ACT003','ACT004','ACT005','ACT006',
                     'ACT007','ACT010','ACT012','ACT017','ACT019','ACT020');

UPDATE public.erp_workspace_records r
SET record_key=m.new_code,
    record_data=jsonb_set(
      jsonb_set(
        jsonb_set(
          jsonb_set(r.record_data,'{كود النشاط}',to_jsonb(m.new_code),true),
          '{ترتيب السطر}',to_jsonb(m.new_order::text),true
        ),
        '{نشط}',to_jsonb('true'::text),true
      ),
      '{يظهر في التطبيق}',to_jsonb('true'::text),true
    ),
    updated_at=now()
FROM _activity_master_recode m
WHERE r.page_key='أنواع الأنشطة'
  AND r.record_key='__TMP_'||m.old_code
  AND m.keep_row;

DELETE FROM public.activity_types WHERE code LIKE '__REMOVED_ACT%';

-- Fail the migration if any category or reference was lost or any code is missing.
DO $$
DECLARE v_total integer; v_active integer; v_categories integer; v_orphans integer; v_workspace integer;
BEGIN
  SELECT count(*) INTO v_total FROM public.activity_types;
  SELECT count(*) INTO v_active FROM public.activity_types
  WHERE code IN ('ACT001','ACT002','ACT003','ACT004','ACT005','ACT006',
                 'ACT007','ACT008','ACT009','ACT010','ACT011','ACT012')
    AND is_active AND show_in_app;
  SELECT count(*) INTO v_categories FROM public.erp_item_categories;
  SELECT count(*) INTO v_orphans FROM public.erp_item_categories
  WHERE activity_code NOT IN ('01','02','03','04','05','06','07','08','09','10','11','12');
  SELECT count(*) INTO v_workspace FROM public.erp_workspace_records WHERE page_key='أنواع الأنشطة';
  IF v_total<>12 OR v_active<>12 OR v_categories<>1170 OR v_orphans<>0 OR v_workspace<>12 THEN
    RAISE EXCEPTION 'Postcondition failed: total %, active %, categories %, invalid category links %, workspace rows %',
      v_total,v_active,v_categories,v_orphans,v_workspace;
  END IF;
END $$;

COMMIT;
