BEGIN;

-- Rebuild category codes from the current activity code and the configured
-- 2+2+2 hierarchy. UUIDs, parent_id, images and all category metadata remain unchanged.
DO $preflight$
DECLARE
  v_count integer;
  v_bad_policy integer;
  v_bad_tree integer;
BEGIN
  SELECT count(*) INTO v_count FROM public.erp_item_categories;
  IF v_count = 0 THEN
    RAISE EXCEPTION 'لا توجد فئات لإعادة تكويدها';
  END IF;

  SELECT count(*) INTO v_bad_policy
  FROM (
    SELECT DISTINCT c.company_id
    FROM public.erp_item_categories c
    LEFT JOIN public.erp_program_policies p
      ON p.company_id=c.company_id AND p.policy_key='code_generation_registry'
    WHERE p.policy_value IS NULL
       OR coalesce((p.policy_value::jsonb #>> '{category_segments,main}')::integer,2) <> 2
       OR coalesce((p.policy_value::jsonb #>> '{category_segments,sub}')::integer,2) <> 2
       OR coalesce((p.policy_value::jsonb #>> '{category_segments,secondary}')::integer,2) <> 2
  ) invalid;
  IF v_bad_policy > 0 THEN
    RAISE EXCEPTION 'سياسة تكويد فئات الأصناف غير موجودة أو لا تطابق 2+2+2 لدى % شركة',v_bad_policy;
  END IF;

  SELECT count(*) INTO v_bad_tree
  FROM public.erp_item_categories c
  LEFT JOIN public.erp_item_categories p ON p.id=c.parent_id AND p.company_id=c.company_id
  WHERE (c.parent_id IS NOT NULL AND p.id IS NULL)
     OR (c.activity_code !~ '^[0-9]{2}$')
     OR (p.id IS NOT NULL AND p.activity_code IS DISTINCT FROM c.activity_code)
     OR (p.id IS NOT NULL AND p.parent_id IS NOT NULL AND EXISTS (
          SELECT 1 FROM public.erp_item_categories gp
          WHERE gp.id=p.parent_id AND gp.parent_id IS NOT NULL
        ));
  IF v_bad_tree > 0 THEN
    RAISE EXCEPTION 'يوجد % سجل فئة بعلاقة أب غير صالحة أو نشاط غير مطابق؛ أوقفت إعادة التكويد دون تعديل',v_bad_tree;
  END IF;
END
$preflight$;

CREATE TEMP TABLE _category_recode_map (
  company_id uuid NOT NULL,
  id uuid PRIMARY KEY,
  activity_code text NOT NULL,
  level_no integer NOT NULL,
  old_code text NOT NULL,
  target_code text NOT NULL,
  temp_seq integer NOT NULL,
  temp_code text
) ON COMMIT DROP;

WITH roots AS (
  SELECT c.id,c.company_id,c.activity_code,c.category_code,
         row_number() OVER (
           PARTITION BY c.company_id,c.activity_code
           ORDER BY c.category_code,c.id
         )::integer AS sibling_no
  FROM public.erp_item_categories c
  WHERE c.parent_id IS NULL
),
subs AS (
  SELECT c.id,c.company_id,c.activity_code,c.parent_id,c.category_code,
         r.activity_code||lpad(r.sibling_no::text,2,'0') AS target_parent_code,
         row_number() OVER (
           PARTITION BY c.company_id,c.parent_id
           ORDER BY c.category_code,c.id
         )::integer AS sibling_no
  FROM public.erp_item_categories c
  JOIN roots r ON r.id=c.parent_id
),
secondary AS (
  SELECT c.id,c.company_id,c.activity_code,c.parent_id,c.category_code,
         s.target_parent_code||lpad(s.sibling_no::text,2,'0') AS target_parent_code,
         row_number() OVER (
           PARTITION BY c.company_id,c.parent_id
           ORDER BY c.category_code,c.id
         )::integer AS sibling_no
  FROM public.erp_item_categories c
  JOIN subs s ON s.id=c.parent_id
),
targets AS (
  SELECT id,company_id,activity_code,0 AS level_no,category_code AS old_code,
         activity_code||lpad(sibling_no::text,2,'0') AS target_code
  FROM roots
  UNION ALL
  SELECT id,company_id,activity_code,1,category_code,
         target_parent_code||lpad(sibling_no::text,2,'0')
  FROM subs
  UNION ALL
  SELECT id,company_id,activity_code,2,category_code,
         target_parent_code||lpad(sibling_no::text,2,'0')
  FROM secondary
)
INSERT INTO _category_recode_map
  (company_id,id,activity_code,level_no,old_code,target_code,temp_seq)
SELECT company_id,id,activity_code,level_no,old_code,target_code,
       row_number() OVER (PARTITION BY company_id,length(old_code) ORDER BY id)::integer
FROM targets;

DO $mapping_check$
DECLARE
  v_total integer;
  v_mapped integer;
  v_overflow integer;
BEGIN
  SELECT count(*) INTO v_total FROM public.erp_item_categories;
  SELECT count(*) INTO v_mapped FROM _category_recode_map;
  IF v_total<>v_mapped THEN
    RAISE EXCEPTION 'لم تكتمل خريطة التكويد: % من % فئة فقط',v_mapped,v_total;
  END IF;
  SELECT count(*) INTO v_overflow
  FROM (
    SELECT company_id,activity_code,parent_id,count(*) AS n
    FROM public.erp_item_categories
    GROUP BY company_id,activity_code,parent_id
    HAVING count(*)>99
  ) x;
  IF v_overflow>0 THEN
    RAISE EXCEPTION 'يوجد % مجموعة تتجاوز سعة مقطعين (99 فئة)',v_overflow;
  END IF;
END
$mapping_check$;

-- Reserve unused numeric codes of the same length for every row first. This
-- prevents collisions while compacting old, inconsistent category codes.
UPDATE _category_recode_map m
SET temp_code = (
  SELECT gs::text
  FROM generate_series(
    CASE length(m.old_code) WHEN 4 THEN 1000 WHEN 6 THEN 100000 ELSE 10000000 END,
    CASE length(m.old_code) WHEN 4 THEN 9999 WHEN 6 THEN 999999 ELSE 99999999 END
  ) AS gs
  WHERE NOT EXISTS (
    SELECT 1 FROM public.erp_item_categories c
    WHERE c.company_id=m.company_id AND c.category_code=gs::text
  )
  AND NOT EXISTS (
    SELECT 1 FROM _category_recode_map t
    WHERE t.company_id=m.company_id AND t.target_code=gs::text
  )
  ORDER BY gs
  OFFSET (m.temp_seq-1) LIMIT 1
);

DO $temp_check$
DECLARE v_missing integer; v_duplicates integer;
BEGIN
  SELECT count(*) INTO v_missing FROM _category_recode_map WHERE temp_code IS NULL;
  SELECT count(*) INTO v_duplicates
  FROM (
    SELECT company_id,temp_code,count(*) n
    FROM _category_recode_map GROUP BY company_id,temp_code HAVING count(*)>1
  ) d;
  IF v_missing>0 OR v_duplicates>0 THEN
    RAISE EXCEPTION 'تعذر حجز أكواد مؤقتة آمنة: مفقود % ومكرر %',v_missing,v_duplicates;
  END IF;
END
$temp_check$;

-- Stage all rows without changing UUIDs or parent links.
DO $stage$
DECLARE r record;
BEGIN
  FOR r IN SELECT id,company_id,temp_code FROM _category_recode_map ORDER BY company_id,level_no DESC,id LOOP
    UPDATE public.erp_item_categories
    SET category_code=r.temp_code
    WHERE id=r.id AND company_id=r.company_id;
  END LOOP;
END
$stage$;

-- Final codes are written from the top of the hierarchy down, using the
-- actual category-code policy: activity(2) + main(2) + sub(2) + secondary(2).
DO $apply$
DECLARE r record;
BEGIN
  FOR r IN SELECT id,company_id,target_code FROM _category_recode_map WHERE level_no=0 ORDER BY company_id,activity_code,target_code LOOP
    UPDATE public.erp_item_categories SET category_code=r.target_code
    WHERE id=r.id AND company_id=r.company_id;
  END LOOP;
  FOR r IN SELECT id,company_id,target_code FROM _category_recode_map WHERE level_no=1 ORDER BY company_id,target_code LOOP
    UPDATE public.erp_item_categories SET category_code=r.target_code
    WHERE id=r.id AND company_id=r.company_id;
  END LOOP;
  FOR r IN SELECT id,company_id,target_code FROM _category_recode_map WHERE level_no=2 ORDER BY company_id,target_code LOOP
    UPDATE public.erp_item_categories SET category_code=r.target_code
    WHERE id=r.id AND company_id=r.company_id;
  END LOOP;
END
$apply$;

DO $verify$
DECLARE
  v_total integer;
  v_bad integer;
  v_missing integer;
BEGIN
  SELECT count(*) INTO v_total FROM public.erp_item_categories;
  SELECT count(*) INTO v_missing
  FROM _category_recode_map m
  LEFT JOIN public.erp_item_categories c ON c.id=m.id AND c.company_id=m.company_id
  WHERE c.id IS NULL OR c.category_code IS DISTINCT FROM m.target_code;
  SELECT count(*) INTO v_bad
  FROM public.erp_item_categories c
  LEFT JOIN public.erp_item_categories p ON p.id=c.parent_id AND p.company_id=c.company_id
  WHERE (c.parent_id IS NULL AND (
           length(c.category_code)<>4 OR left(c.category_code,2)<>c.activity_code
        ))
     OR (c.parent_id IS NOT NULL AND (
           p.id IS NULL OR c.category_code<>p.category_code||right(c.category_code,2)
           OR length(c.category_code)<>length(p.category_code)+2
        ));
  IF v_total<>(SELECT count(*) FROM _category_recode_map) OR v_missing>0 OR v_bad>0 THEN
    RAISE EXCEPTION 'فشل التحقق النهائي: الإجمالي %، اختلاف الخريطة %، أخطاء الهرمية %',v_total,v_missing,v_bad;
  END IF;
END
$verify$;

COMMIT;