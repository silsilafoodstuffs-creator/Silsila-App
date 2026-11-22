BEGIN;
SET LOCAL statement_timeout = '120s';

DO $preflight$
DECLARE v_count integer; v_bad_policy integer; v_bad_tree integer;
BEGIN
  SELECT count(*) INTO v_count FROM public.erp_item_categories;
  IF v_count=0 THEN RAISE EXCEPTION 'لا توجد فئات لإعادة تكويدها'; END IF;

  SELECT count(*) INTO v_bad_policy
  FROM (
    SELECT DISTINCT c.company_id
    FROM public.erp_item_categories c
    LEFT JOIN public.erp_program_policies p
      ON p.company_id=c.company_id AND p.policy_key='code_generation_registry'
    WHERE p.policy_value IS NULL
       OR coalesce((p.policy_value::jsonb #>> '{category_segments,main}')::integer,2)<>2
       OR coalesce((p.policy_value::jsonb #>> '{category_segments,sub}')::integer,2)<>2
       OR coalesce((p.policy_value::jsonb #>> '{category_segments,secondary}')::integer,2)<>2
  ) invalid;
  IF v_bad_policy>0 THEN RAISE EXCEPTION 'سياسة تكويد الفئات غير مطابقة 2+2+2 لدى % شركة',v_bad_policy; END IF;

  SELECT count(*) INTO v_bad_tree
  FROM public.erp_item_categories c
  LEFT JOIN public.erp_item_categories p ON p.id=c.parent_id AND p.company_id=c.company_id
  WHERE (c.parent_id IS NOT NULL AND p.id IS NULL)
     OR c.activity_code !~ '^[0-9]{2}$'
     OR (p.id IS NOT NULL AND p.activity_code IS DISTINCT FROM c.activity_code)
     OR (p.id IS NOT NULL AND p.parent_id IS NOT NULL AND EXISTS (
       SELECT 1 FROM public.erp_item_categories gp
       WHERE gp.id=p.parent_id AND gp.parent_id IS NOT NULL
     ));
  IF v_bad_tree>0 THEN RAISE EXCEPTION 'يوجد % سجل بعلاقة أب أو نشاط غير صالح؛ لم يتم تعديل أي فئة',v_bad_tree; END IF;
END
$preflight$;

CREATE TEMP TABLE _category_recode_map (
 company_id uuid NOT NULL,id uuid PRIMARY KEY,activity_code text NOT NULL,
 level_no integer NOT NULL,old_code text NOT NULL,target_code text NOT NULL,
 temp_seq integer NOT NULL,temp_code text NOT NULL
) ON COMMIT DROP;

WITH roots AS (
 SELECT c.id,c.company_id,c.activity_code,c.category_code,
  row_number() OVER(PARTITION BY c.company_id,c.activity_code ORDER BY c.category_code,c.id)::integer sibling_no
 FROM public.erp_item_categories c WHERE c.parent_id IS NULL
), subs AS (
 SELECT c.id,c.company_id,c.activity_code,c.parent_id,c.category_code,
  r.activity_code||lpad(r.sibling_no::text,2,'0') target_parent_code,
  row_number() OVER(PARTITION BY c.company_id,c.parent_id ORDER BY c.category_code,c.id)::integer sibling_no
 FROM public.erp_item_categories c JOIN roots r ON r.id=c.parent_id
), secondary AS (
 SELECT c.id,c.company_id,c.activity_code,c.parent_id,c.category_code,
  s.target_parent_code||lpad(s.sibling_no::text,2,'0') target_parent_code,
  row_number() OVER(PARTITION BY c.company_id,c.parent_id ORDER BY c.category_code,c.id)::integer sibling_no
 FROM public.erp_item_categories c JOIN subs s ON s.id=c.parent_id
), targets AS (
 SELECT id,company_id,activity_code,0 level_no,category_code old_code,
  activity_code||lpad(sibling_no::text,2,'0') target_code FROM roots
 UNION ALL
 SELECT id,company_id,activity_code,1,category_code,
  target_parent_code||lpad(sibling_no::text,2,'0') FROM subs
 UNION ALL
 SELECT id,company_id,activity_code,2,category_code,
  target_parent_code||lpad(sibling_no::text,2,'0') FROM secondary
), sequenced AS (
 SELECT *,row_number() OVER(PARTITION BY company_id,length(old_code) ORDER BY id)::integer temp_seq
 FROM targets
)
INSERT INTO _category_recode_map
SELECT company_id,id,activity_code,level_no,old_code,target_code,temp_seq,
 CASE length(old_code)
  WHEN 4 THEN lpad((9000+temp_seq)::text,4,'0')
  WHEN 6 THEN lpad((900000+temp_seq)::text,6,'0')
  WHEN 8 THEN lpad((90000000+temp_seq)::text,8,'0')
 END
FROM sequenced;

DO $mapping_check$
DECLARE v_total integer; v_mapped integer; v_bad integer; v_overflow integer;
BEGIN
 SELECT count(*) INTO v_total FROM public.erp_item_categories;
 SELECT count(*) INTO v_mapped FROM _category_recode_map;
 IF v_total<>v_mapped THEN RAISE EXCEPTION 'خريطة التكويد غير مكتملة: % من %',v_mapped,v_total; END IF;

 SELECT count(*) INTO v_bad FROM (
  SELECT company_id,target_code,count(*) n FROM _category_recode_map
  GROUP BY company_id,target_code HAVING count(*)>1
 ) d;
 IF v_bad>0 THEN RAISE EXCEPTION 'يوجد % كود نهائي مكرر في خريطة التكويد',v_bad; END IF;

 SELECT count(*) INTO v_bad
 FROM public.erp_item_categories c JOIN _category_recode_map m
 ON c.company_id=m.company_id AND c.category_code=m.temp_code;
 IF v_bad>0 THEN RAISE EXCEPTION 'نطاق الأكواد المؤقتة محجوز مسبقًا؛ لم يتم تعديل البيانات'; END IF;

 SELECT count(*) INTO v_overflow FROM (
  SELECT company_id,activity_code,parent_id,count(*) n
  FROM public.erp_item_categories GROUP BY company_id,activity_code,parent_id HAVING count(*)>99
 ) x;
 IF v_overflow>0 THEN RAISE EXCEPTION 'توجد مجموعات تتجاوز 99 فئة في المستوى الواحد'; END IF;
END
$mapping_check$;

-- Move every current code to a unique same-length temporary code first.
UPDATE public.erp_item_categories c
SET category_code=m.temp_code
FROM _category_recode_map m
WHERE c.id=m.id AND c.company_id=m.company_id;

-- Then apply the compact activity-rooted code path to all three levels.
UPDATE public.erp_item_categories c
SET category_code=m.target_code
FROM _category_recode_map m
WHERE c.id=m.id AND c.company_id=m.company_id;

DO $verify$
DECLARE v_total integer; v_missing integer; v_bad integer;
BEGIN
 SELECT count(*) INTO v_total FROM public.erp_item_categories;
 SELECT count(*) INTO v_missing
 FROM _category_recode_map m
 LEFT JOIN public.erp_item_categories c ON c.id=m.id AND c.company_id=m.company_id
 WHERE c.id IS NULL OR c.category_code IS DISTINCT FROM m.target_code;

 SELECT count(*) INTO v_bad
 FROM public.erp_item_categories c
 LEFT JOIN public.erp_item_categories p ON p.id=c.parent_id AND p.company_id=c.company_id
 WHERE (c.parent_id IS NULL AND (length(c.category_code)<>4 OR left(c.category_code,2)<>c.activity_code))
    OR (c.parent_id IS NOT NULL AND (
       p.id IS NULL OR length(c.category_code)<>length(p.category_code)+2
       OR left(c.category_code,length(p.category_code))<>p.category_code
    ));
 IF v_total<>(SELECT count(*) FROM _category_recode_map) OR v_missing>0 OR v_bad>0 THEN
  RAISE EXCEPTION 'فشل التحقق: الإجمالي %، أكواد غير مطابقة %، أخطاء هرمية %',v_total,v_missing,v_bad;
 END IF;
END
$verify$;
COMMIT;