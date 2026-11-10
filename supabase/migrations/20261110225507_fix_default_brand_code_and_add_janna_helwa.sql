BEGIN;

-- Ensure the requested combined brand exists for every company with an item catalog.
-- The brand-code trigger assigns the next available BraNN code.
INSERT INTO public.erp_brands(company_id,brand_code,brand_name,is_active,is_system)
SELECT companies.company_id,'','جنة حلوة',true,false
FROM (
  SELECT company_id FROM public.erp_item_categories
  UNION
  SELECT company_id FROM public.erp_items
) companies
WHERE NOT EXISTS (
  SELECT 1 FROM public.erp_brands b
  WHERE b.company_id=companies.company_id
    AND lower(btrim(b.brand_name))=lower('جنة حلوة')
);

-- After the brand-width migration the system brand is Bra00, not the old Bra000.
-- Resolve the default through the active brand policy so the prefix/width remain centralized.
CREATE OR REPLACE FUNCTION public.erp_assign_item_hierarchical_code()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO ''
AS $function$
DECLARE
  v_policy jsonb := '{}'::jsonb;
  v_item_prefix text := 'Itm';
  v_brand_prefix text := 'Bra';
  v_brand_digits integer := 2;
  v_serial_digits integer := 3;
  v_main_digits integer := 2;
  v_sub_digits integer := 2;
  v_secondary_digits integer := 2;
  v_category_code text;
  v_category_digits text;
  v_brand_code text;
  v_brand_name text;
  v_resolved_brand_id uuid;
  v_brand_digits_value text;
  v_serial_max numeric;
  v_serial bigint;
  v_lock text;
BEGIN
  IF TG_OP='UPDATE'
     AND NEW.category_id IS NOT DISTINCT FROM OLD.category_id
     AND NEW.brand_id IS NOT DISTINCT FROM OLD.brand_id
     AND NEW.item_code IS NOT DISTINCT FROM OLD.item_code
     AND nullif(NEW.item_code,'') IS NOT NULL THEN
    RETURN NEW;
  END IF;

  IF NEW.category_id IS NULL THEN
    RAISE EXCEPTION 'اختر الفئة الثانوية قبل حفظ الصنف لتوليد كوده';
  END IF;

  SELECT CASE WHEN left(p.policy_value,1)='{' THEN p.policy_value::jsonb ELSE '{}'::jsonb END
    INTO v_policy
  FROM public.erp_program_policies p
  WHERE p.company_id=NEW.company_id AND p.policy_key='code_generation_registry'
  LIMIT 1;

  v_item_prefix:=coalesce(nullif(v_policy->>'item_prefix',''),'Itm');
  v_main_digits:=coalesce(nullif(v_policy #>> '{category_segments,main}','')::integer,
                           nullif(v_policy #>> '{item_segments,main}','')::integer,2);
  v_sub_digits:=coalesce(nullif(v_policy #>> '{category_segments,sub}','')::integer,
                         nullif(v_policy #>> '{item_segments,sub}','')::integer,2);
  v_secondary_digits:=coalesce(nullif(v_policy #>> '{category_segments,secondary}','')::integer,
                               nullif(v_policy #>> '{item_segments,secondary}','')::integer,2);
  v_serial_digits:=coalesce(nullif(v_policy #>> '{item_segments,serial}','')::integer,3);

  SELECT c.prefix,c.digits INTO v_brand_prefix,v_brand_digits
  FROM public.erp_code_policy_config(NEW.company_id,'brand','Bra',2) c;

  IF v_item_prefix !~ '^[A-Za-z]{3}$'
     OR v_main_digits NOT BETWEEN 1 AND 6
     OR v_sub_digits NOT BETWEEN 1 AND 6
     OR v_secondary_digits NOT BETWEEN 1 AND 6
     OR v_serial_digits NOT BETWEEN 1 AND 8
     OR v_brand_prefix !~ '^[A-Za-z]{3}$'
     OR v_brand_digits NOT BETWEEN 1 AND 6 THEN
    RAISE EXCEPTION 'إعدادات تكويد الأصناف أو البراندات غير صحيحة؛ راجع سياسات الأكواد';
  END IF;

  SELECT c.category_code INTO v_category_code
  FROM public.erp_item_categories c
  WHERE c.id=NEW.category_id
    AND c.company_id=NEW.company_id
    AND c.is_active=true
    AND c.parent_id IS NOT NULL
    AND EXISTS (
      SELECT 1 FROM public.erp_item_categories p
      WHERE p.id=c.parent_id AND p.company_id=c.company_id AND p.parent_id IS NOT NULL
    );

  IF v_category_code IS NULL THEN
    RAISE EXCEPTION 'الفئة المختارة ليست فئة ثانوية نشطة مرتبطة بفئة رئيسية وفرعية';
  END IF;

  v_category_digits:=regexp_replace(v_category_code,'[^0-9]','','g');
  IF length(v_category_digits)<>(v_main_digits+v_sub_digits+v_secondary_digits) THEN
    RAISE EXCEPTION 'كود الفئة الثانوية لا يطابق أطوال أجزاء سياسة الفئات';
  END IF;

  IF NEW.brand_id IS NULL AND nullif(btrim(coalesce(NEW.brand_name,'')),'') IS NOT NULL THEN
    SELECT b.id INTO v_resolved_brand_id
    FROM public.erp_brands b
    WHERE b.company_id=NEW.company_id
      AND lower(btrim(b.brand_name))=lower(btrim(NEW.brand_name))
    ORDER BY b.is_active DESC
    LIMIT 1;
    NEW.brand_id:=v_resolved_brand_id;
  END IF;

  IF NEW.brand_id IS NULL THEN
    SELECT b.id INTO NEW.brand_id
    FROM public.erp_brands b
    WHERE b.company_id=NEW.company_id
      AND b.brand_code=v_brand_prefix||lpad('0',v_brand_digits,'0')
      AND b.is_active=true
    LIMIT 1;
  END IF;

  SELECT b.brand_code,b.brand_name INTO v_brand_code,v_brand_name
  FROM public.erp_brands b
  WHERE b.id=NEW.brand_id
    AND b.company_id=NEW.company_id
    AND b.is_active=true;

  IF v_brand_code IS NULL THEN
    RAISE EXCEPTION 'اختر براندًا/ماركة نشطة من دليل البراندات التابع للشركة';
  END IF;

  IF v_brand_code !~ ('^'||v_brand_prefix||'[0-9]{'||v_brand_digits||'}$') THEN
    RAISE EXCEPTION 'كود البراند لا يطابق سياسة تكويده الحالية';
  END IF;

  v_brand_digits_value:=regexp_replace(v_brand_code,'[^0-9]','','g');
  IF length(v_brand_digits_value)<>v_brand_digits THEN
    RAISE EXCEPTION 'عدد أرقام البراند لا يطابق سياسة الأكواد';
  END IF;

  NEW.brand_name:=v_brand_name;
  v_lock:=NEW.company_id::text||':item:'||v_item_prefix||v_category_digits||v_brand_digits_value;
  PERFORM pg_advisory_xact_lock(hashtextextended(v_lock,0));

  v_serial_max:=power(10::numeric,v_serial_digits)-1;
  SELECT coalesce(max(right(i.item_code,v_serial_digits)::bigint),0)
    INTO v_serial
  FROM public.erp_items i
  WHERE i.company_id=NEW.company_id
    AND i.id IS DISTINCT FROM NEW.id
    AND i.item_code ~ ('^'||v_item_prefix||v_category_digits||v_brand_digits_value||'[0-9]{'||v_serial_digits||'}$');

  IF coalesce(v_serial,0)>=v_serial_max THEN
    RAISE EXCEPTION 'انتهى تسلسل الأصناف لهذه الفئة والبراند؛ زد خانات التسلسل من سياسات التكويد';
  END IF;

  NEW.item_code:=v_item_prefix||v_category_digits||v_brand_digits_value||
    lpad((coalesce(v_serial,0)+1)::text,v_serial_digits,'0');
  RETURN NEW;
END;
$function$;

REVOKE ALL ON FUNCTION public.erp_assign_item_hierarchical_code() FROM PUBLIC,anon,authenticated;

DO $verify$
BEGIN
  IF EXISTS (
    SELECT 1
    FROM public.erp_items i
    LEFT JOIN public.erp_brands b
      ON b.id=i.brand_id AND b.company_id=i.company_id AND b.is_active=true
    WHERE i.brand_id IS NOT NULL AND b.id IS NULL
  ) THEN
    RAISE EXCEPTION 'فشل التحقق: توجد أصناف مرتبطة ببراند غير صالح';
  END IF;
END;
$verify$;

COMMIT;
