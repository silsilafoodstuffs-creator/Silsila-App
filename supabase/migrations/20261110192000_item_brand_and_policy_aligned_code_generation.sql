BEGIN;

CREATE TABLE IF NOT EXISTS public.erp_brands (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  company_id uuid NOT NULL,
  brand_code text NOT NULL DEFAULT '',
  brand_name text NOT NULL,
  brand_name_en text,
  is_active boolean NOT NULL DEFAULT true,
  is_system boolean NOT NULL DEFAULT false,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT erp_brands_company_id_id_uq UNIQUE (company_id,id),
  CONSTRAINT erp_brands_company_code_uq UNIQUE (company_id,brand_code)
);

CREATE UNIQUE INDEX IF NOT EXISTS erp_brands_company_name_ci_uq
  ON public.erp_brands (company_id, lower(btrim(brand_name)));
CREATE INDEX IF NOT EXISTS erp_brands_company_active_name_idx
  ON public.erp_brands (company_id,is_active,brand_name);

ALTER TABLE public.erp_brands ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS erp_brands_member_access ON public.erp_brands;
CREATE POLICY erp_brands_member_access ON public.erp_brands
  FOR ALL TO authenticated
  USING (public.erp_user_can_access_company(company_id))
  WITH CHECK (public.erp_user_can_access_company(company_id));
GRANT SELECT,INSERT,UPDATE,DELETE ON public.erp_brands TO authenticated;

ALTER TABLE public.erp_items
  ADD COLUMN IF NOT EXISTS brand_id uuid;

DO $constraint$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint
    WHERE conname='erp_items_brand_company_fk'
      AND conrelid='public.erp_items'::regclass
  ) THEN
    ALTER TABLE public.erp_items
      ADD CONSTRAINT erp_items_brand_company_fk
      FOREIGN KEY (company_id,brand_id)
      REFERENCES public.erp_brands(company_id,id)
      ON DELETE RESTRICT;
  END IF;
END;
$constraint$;

CREATE OR REPLACE FUNCTION public.erp_assign_brand_code()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO ''
AS $function$
DECLARE
  v_prefix text;
  v_digits integer;
  v_max bigint;
  v_lock text;
BEGIN
  IF NEW.company_id IS NULL THEN
    RAISE EXCEPTION 'الشركة مطلوبة لتوليد كود البراند';
  END IF;

  SELECT c.prefix,c.digits INTO v_prefix,v_digits
  FROM public.erp_code_policy_config(NEW.company_id,'brand','Bra',3) c;

  IF NEW.brand_code IS NOT NULL AND btrim(NEW.brand_code)<>'' THEN
    IF NEW.brand_code !~ ('^'||v_prefix||'[0-9]{'||v_digits||'}$') THEN
      RAISE EXCEPTION 'كود البراند يجب أن يطابق سياسة % وعدد خاناتها %',v_prefix,v_digits;
    END IF;
    RETURN NEW;
  END IF;

  v_lock:=NEW.company_id::text||':brand:'||v_prefix;
  PERFORM pg_advisory_xact_lock(hashtextextended(v_lock,0));

  SELECT coalesce(max(substring(b.brand_code from (length(v_prefix)+1))::bigint),0)
    INTO v_max
  FROM public.erp_brands b
  WHERE b.company_id=NEW.company_id
    AND b.brand_code ~ ('^'||v_prefix||'[0-9]{'||v_digits||'}$');

  IF coalesce(v_max,0)>=power(10::numeric,v_digits)-1 THEN
    RAISE EXCEPTION 'انتهت خانات أكواد البراند؛ زد عدد الخانات من سياسات التكويد';
  END IF;

  NEW.brand_code:=v_prefix||lpad((coalesce(v_max,0)+1)::text,v_digits,'0');
  RETURN NEW;
END;
$function$;

REVOKE ALL ON FUNCTION public.erp_assign_brand_code() FROM PUBLIC,anon,authenticated;
DROP TRIGGER IF EXISTS erp_brands_assign_code ON public.erp_brands;
CREATE TRIGGER erp_brands_assign_code
BEFORE INSERT ON public.erp_brands
FOR EACH ROW EXECUTE FUNCTION public.erp_assign_brand_code();

DROP TRIGGER IF EXISTS erp_brands_updated_at ON public.erp_brands;
CREATE TRIGGER erp_brands_updated_at
BEFORE UPDATE ON public.erp_brands
FOR EACH ROW EXECUTE FUNCTION public.erp_set_updated_at();

WITH brand_catalog(sort_order,brand_name) AS (
  VALUES
  (0,'بدون علامة تجارية'),
(1,'جهينة'),
(2,'بيتي'),
(3,'روابي'),
(4,'جنة'),
(5,'حلوة'),
(6,'لمار'),
(7,'المراعي'),
(8,'دومتي'),
(9,'رودس'),
(10,'عبورلاند'),
(11,'سن توب'),
(12,'إيديتا'),
(13,'لمبادا'),
(14,'الشمعدان'),
(15,'الملكة'),
(16,'حواء'),
(17,'إيطاليانو'),
(18,'ريجينا'),
(19,'حبوبة'),
(20,'الضحى'),
(21,'ريحانة'),
(22,'صافولا'),
(23,'أرما'),
(24,'أوكسي'),
(25,'برسيل'),
(26,'كادبري'),
(27,'جلاكسي'),
(28,'ماكسي كولا'),
(29,'بيبسي'),
(30,'سفن'),
(31,'ميراندا'),
(32,'كوكاكولا'),
(33,'سبرايت'),
(34,'فانتا'),
(35,'ريدبول'),
(36,'تويست'),
(37,'بيريل'),
(38,'فيروز'),
(39,'راني'),
(40,'فرجللو'),
(41,'شيبسي'),
(42,'بيج شيبس'),
(43,'تايجر'),
(44,'إيجيبت فودز'),
(45,'ماربيلا'),
(46,'سندباد'),
(47,'صني'),
(48,'حلو الشام'),
(49,'كوكس'),
(50,'العروسة'),
(51,'ليبتون'),
(52,'هاينز'),
(53,'كنور'),
(54,'يونيليفر'),
(55,'أريال'),
(56,'ڤانيش'),
(57,'كلوركس'),
(58,'سافانا'),
(59,'دريم'),
(60,'فيوري'),
(61,'بسكو مصر'),
(62,'أولكر'),
(63,'بيسكاتو'),
(64,'ڤي سڤن'),
(65,'فيبا'),
(66,'تايد'),
(67,'البوادي')
),
companies AS (
  SELECT company_id FROM public.erp_item_categories
  UNION
  SELECT company_id FROM public.erp_items
),
numbered AS (
  SELECT c.company_id,b.sort_order,b.brand_name,
         CASE WHEN b.sort_order=0 THEN 'Bra000'
              ELSE 'Bra'||lpad(b.sort_order::text,3,'0') END AS brand_code,
         (b.sort_order=0) AS is_system
  FROM companies c CROSS JOIN brand_catalog b
)
INSERT INTO public.erp_brands(company_id,brand_code,brand_name,is_active,is_system)
SELECT company_id,brand_code,brand_name,true,is_system
FROM numbered
ON CONFLICT (company_id,brand_code) DO NOTHING;

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
  v_brand_digits integer := 3;
  v_serial_digits integer := 3;
  v_main_digits integer := 2;
  v_sub_digits integer := 2;
  v_secondary_digits integer := 2;
  v_category_code text;
  v_category_digits text;
  v_brand_code text;
  v_brand_name text;
  v_brand_digits_value text;
  v_serial_max numeric;
  v_serial bigint;
  v_lock text;
BEGIN
  IF TG_OP='UPDATE'
     AND NEW.category_id IS NOT DISTINCT FROM OLD.category_id
     AND NEW.brand_id IS NOT DISTINCT FROM OLD.brand_id THEN
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
  FROM public.erp_code_policy_config(NEW.company_id,'brand','Bra',3) c;

  IF v_item_prefix !~ '^[A-Za-z]{3}$'
     OR v_main_digits NOT BETWEEN 1 AND 6
     OR v_sub_digits NOT BETWEEN 1 AND 6
     OR v_secondary_digits NOT BETWEEN 1 AND 6
     OR v_serial_digits NOT BETWEEN 1 AND 8 THEN
    RAISE EXCEPTION 'إعدادات تكويد الأصناف غير صحيحة؛ راجع سياسات الأكواد';
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
    SELECT b.id INTO NEW.brand_id
    FROM public.erp_brands b
    WHERE b.company_id=NEW.company_id
      AND lower(btrim(b.brand_name))=lower(btrim(NEW.brand_name))
    ORDER BY b.is_active DESC
    LIMIT 1;
  END IF;

  IF NEW.brand_id IS NULL THEN
    SELECT b.id INTO NEW.brand_id
    FROM public.erp_brands b
    WHERE b.company_id=NEW.company_id AND b.brand_code='Bra000'
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
DROP TRIGGER IF EXISTS erp_items_hierarchical_code ON public.erp_items;
CREATE TRIGGER erp_items_hierarchical_code
BEFORE INSERT OR UPDATE OF category_id,brand_id
ON public.erp_items
FOR EACH ROW EXECUTE FUNCTION public.erp_assign_item_hierarchical_code();

CREATE OR REPLACE FUNCTION public.erp_item_categories_validate_tree_and_code()
RETURNS trigger
LANGUAGE plpgsql
SET search_path TO ''
AS $function$
DECLARE
  v_policy jsonb := '{}'::jsonb;
  v_prefix text := 'Cat';
  v_main_digits integer := 2;
  v_sub_digits integer := 2;
  v_secondary_digits integer := 2;
  v_parent_company uuid;
  v_parent_activity text;
  v_parent_parent_id uuid;
  v_parent_code text;
  v_grandparent_parent_id uuid;
  v_parent_digits text := '';
  v_segment_digits integer;
  v_expected_digits integer;
  v_rank integer;
  v_lock text;
BEGIN
  SELECT CASE WHEN left(p.policy_value,1)='{' THEN p.policy_value::jsonb ELSE '{}'::jsonb END
    INTO v_policy
  FROM public.erp_program_policies p
  WHERE p.company_id=NEW.company_id AND p.policy_key='code_generation_registry'
  LIMIT 1;

  v_prefix:=coalesce(nullif(v_policy->>'category_prefix',''),
                     nullif(v_policy #>> '{types,category,prefix}',''),'Cat');
  v_main_digits:=coalesce(nullif(v_policy #>> '{category_segments,main}','')::integer,2);
  v_sub_digits:=coalesce(nullif(v_policy #>> '{category_segments,sub}','')::integer,2);
  v_secondary_digits:=coalesce(nullif(v_policy #>> '{category_segments,secondary}','')::integer,2);

  IF v_prefix !~ '^[A-Za-z]{3}$'
     OR v_main_digits NOT BETWEEN 1 AND 6
     OR v_sub_digits NOT BETWEEN 1 AND 6
     OR v_secondary_digits NOT BETWEEN 1 AND 6 THEN
    RAISE EXCEPTION 'إعدادات تكويد فئات الأصناف غير صحيحة';
  END IF;

  IF TG_OP='UPDATE' AND NEW.parent_id IS DISTINCT FROM OLD.parent_id THEN
    NEW.category_code:=NULL;
  END IF;

  IF NEW.parent_id IS NOT NULL THEN
    SELECT p.company_id,p.activity_code,p.parent_id,p.category_code
      INTO v_parent_company,v_parent_activity,v_parent_parent_id,v_parent_code
    FROM public.erp_item_categories p
    WHERE p.id=NEW.parent_id;

    IF NOT FOUND THEN
      RAISE EXCEPTION 'الفئة الرئيسية المحددة غير موجودة.';
    END IF;
    IF v_parent_company IS DISTINCT FROM NEW.company_id
       OR v_parent_activity IS DISTINCT FROM NEW.activity_code THEN
      RAISE EXCEPTION 'يجب أن تنتمي الفئة وأصلها إلى الشركة والنشاط نفسيهما.';
    END IF;
    IF NEW.parent_id=NEW.id THEN
      RAISE EXCEPTION 'لا يمكن أن تكون الفئة أصلًا لنفسها.';
    END IF;

    v_parent_digits:=regexp_replace(coalesce(v_parent_code,''),'[^0-9]','','g');
    IF v_parent_digits='' THEN
      RAISE EXCEPTION 'كود الفئة الأعلى غير صالح؛ أعد حفظ الفئة الأعلى أولًا.';
    END IF;

    IF v_parent_parent_id IS NULL THEN
      v_segment_digits:=v_sub_digits;
      v_expected_digits:=v_main_digits+v_sub_digits;
      IF length(v_parent_digits)<>v_main_digits THEN
        RAISE EXCEPTION 'كود الفئة الرئيسية لا يطابق سياسة الفئات الحالية';
      END IF;
    ELSE
      SELECT gp.parent_id INTO v_grandparent_parent_id
      FROM public.erp_item_categories gp
      WHERE gp.id=v_parent_parent_id
        AND gp.company_id=NEW.company_id;
      IF NOT FOUND OR v_grandparent_parent_id IS NOT NULL THEN
        RAISE EXCEPTION 'يسمح بثلاثة مستويات فقط: رئيسية وفرعية وثانوية.';
      END IF;
      v_segment_digits:=v_secondary_digits;
      v_expected_digits:=v_main_digits+v_sub_digits+v_secondary_digits;
      IF length(v_parent_digits)<>(v_main_digits+v_sub_digits) THEN
        RAISE EXCEPTION 'كود الفئة الفرعية لا يطابق سياسة الفئات الحالية';
      END IF;
    END IF;
  ELSE
    v_segment_digits:=v_main_digits;
    v_expected_digits:=v_main_digits;
  END IF;

  IF NEW.category_code IS NULL OR btrim(NEW.category_code)='' THEN
    v_lock:=NEW.company_id::text||':category:'||coalesce(NEW.parent_id::text,'root');
    PERFORM pg_advisory_xact_lock(hashtextextended(v_lock,0));
    SELECT count(*)+1 INTO v_rank
    FROM public.erp_item_categories c
    WHERE c.company_id=NEW.company_id
      AND c.parent_id IS NOT DISTINCT FROM NEW.parent_id
      AND c.id IS DISTINCT FROM NEW.id;

    IF v_rank>power(10::numeric,v_segment_digits)-1 THEN
      RAISE EXCEPTION 'عدد الفئات التابعة تجاوز سعة التكويد المحددة (% خانات)',v_segment_digits;
    END IF;

    NEW.category_code:=v_prefix||v_parent_digits||lpad(v_rank::text,v_segment_digits,'0');
  ELSIF NEW.category_code !~ ('^'||v_prefix||'[0-9]{'||v_expected_digits||'}$') THEN
    RAISE EXCEPTION 'كود الفئة يجب أن يطابق سياسة % وعدد أرقام المستوى %',v_prefix,v_expected_digits;
  END IF;

  RETURN NEW;
END;
$function$;

CREATE OR REPLACE FUNCTION public.erp_assign_geo_hierarchical_code()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO ''
AS $function$
DECLARE
  v_policy jsonb := '{}'::jsonb;
  v_lengths jsonb := '{}'::jsonb;
  v_country_code text;
  v_parent_code text;
  v_segment_digits integer;
  v_next bigint;
  v_lock text;
BEGIN
  IF TG_OP='UPDATE'
     AND NEW.parent_id IS NOT DISTINCT FROM OLD.parent_id
     AND NEW.level IS NOT DISTINCT FROM OLD.level
     AND NEW.hierarchical_code IS NOT NULL THEN
    RETURN NEW;
  END IF;

  SELECT CASE WHEN left(p.policy_value,1)='{' THEN p.policy_value::jsonb ELSE '{}'::jsonb END
    INTO v_policy
  FROM public.erp_program_policies p
  WHERE p.company_id=NEW.company_id AND p.policy_key='code_generation_registry'
  LIMIT 1;
  v_lengths:=coalesce(v_policy->'geo_segment_lengths','{}'::jsonb);

  SELECT c.country_code INTO v_country_code
  FROM public.erp_countries c
  WHERE c.company_id=NEW.company_id AND c.name_ar='مصر' AND c.is_active=true
  ORDER BY c.created_at LIMIT 1;

  IF v_country_code IS NULL OR v_country_code !~ '^[0-9]{2}$' THEN
    RAISE EXCEPTION 'يجب تسجيل كود مصر المكون من رقمين في تبويب بيانات الدول أولًا';
  END IF;

  IF NEW.level='governorate' THEN
    IF NEW.parent_id IS NOT NULL THEN
      RAISE EXCEPTION 'المحافظة يجب أن تكون مستوى رئيسيًا دون أب جغرافي';
    END IF;
    v_segment_digits:=coalesce(nullif(v_lengths->>'governorate','')::integer,2);
    IF v_segment_digits NOT BETWEEN 1 AND 6 THEN
      RAISE EXCEPTION 'عدد خانات المحافظة في سياسة الجغرافيا يجب أن يكون من 1 إلى 6';
    END IF;

    v_lock:=NEW.company_id::text||':governorate';
    PERFORM pg_advisory_xact_lock(hashtextextended(v_lock,0));

    SELECT coalesce(max(substring(g.hierarchical_code from 3)::bigint),0)+1
      INTO v_next
    FROM public.erp_geographic_data g
    WHERE g.company_id=NEW.company_id AND g.level='governorate'
      AND g.hierarchical_code ~ ('^'||v_country_code||'[0-9]{'||v_segment_digits||'}$');

    IF v_next>power(10::numeric,v_segment_digits)-1 THEN
      RAISE EXCEPTION 'تم استنفاد أكواد المحافظات وفق سياسة التكويد';
    END IF;
    NEW.hierarchical_code:=v_country_code||lpad(v_next::text,v_segment_digits,'0');

  ELSIF NEW.level IN ('district','area') THEN
    IF NEW.parent_id IS NULL THEN
      RAISE EXCEPTION 'يجب ربط المركز/الحي أو المنطقة بالمستوى الجغرافي الأعلى';
    END IF;

    SELECT g.hierarchical_code INTO v_parent_code
    FROM public.erp_geographic_data g
    WHERE g.id=NEW.parent_id AND g.company_id=NEW.company_id
      AND g.level=CASE WHEN NEW.level='district' THEN 'governorate' ELSE 'district' END;

    IF v_parent_code IS NULL OR v_parent_code !~ '^[0-9]+$' THEN
      RAISE EXCEPTION 'التسلسل الجغرافي غير صحيح: اربط كل مستوى بأبيه الصحيح';
    END IF;

    v_segment_digits:=CASE WHEN NEW.level='district'
      THEN coalesce(nullif(v_lengths->>'center','')::integer,2)
      ELSE coalesce(nullif(v_lengths->>'area','')::integer,2) END;

    IF v_segment_digits NOT BETWEEN 1 AND 6 THEN
      RAISE EXCEPTION 'عدد خانات المستوى الجغرافي يجب أن يكون من 1 إلى 6';
    END IF;

    v_lock:=NEW.company_id::text||':'||NEW.parent_id::text||':'||NEW.level;
    PERFORM pg_advisory_xact_lock(hashtextextended(v_lock,0));

    SELECT coalesce(max(substring(g.hierarchical_code from length(v_parent_code)+1)::bigint),0)+1
      INTO v_next
    FROM public.erp_geographic_data g
    WHERE g.company_id=NEW.company_id
      AND g.parent_id=NEW.parent_id
      AND g.level=NEW.level
      AND g.hierarchical_code ~ ('^'||v_parent_code||'[0-9]{'||v_segment_digits||'}$');

    IF v_next>power(10::numeric,v_segment_digits)-1 THEN
      RAISE EXCEPTION 'تم استنفاد الأكواد التابعة لهذا المستوى وفق سياسة التكويد';
    END IF;

    NEW.hierarchical_code:=v_parent_code||lpad(v_next::text,v_segment_digits,'0');
  ELSE
    RAISE EXCEPTION 'مستوى جغرافي غير مدعوم: %',NEW.level;
  END IF;

  RETURN NEW;
END;
$function$;

CREATE OR REPLACE FUNCTION public.erp_assign_customer_geo_code()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO ''
AS $function$
DECLARE
  v_geo_code text;
  v_country_code text;
  v_policy jsonb := '{}'::jsonb;
  v_lengths jsonb := '{}'::jsonb;
  v_prefix text := 'Cus';
  v_digits integer := 2;
  v_geo_digits integer;
  v_max bigint;
  v_lock text;
BEGIN
  IF coalesce(NEW.party_kind,'')<>'customer' OR nullif(NEW.party_code,'') IS NOT NULL THEN
    RETURN NEW;
  END IF;
  IF NEW.geo_area_id IS NULL THEN
    RAISE EXCEPTION 'اختيار المنطقة مطلوب لتوليد كود العميل المرتبط بالتقسيم الجغرافي';
  END IF;

  SELECT g.hierarchical_code INTO v_geo_code
  FROM public.erp_geographic_data g
  WHERE g.id=NEW.geo_area_id AND g.company_id=NEW.company_id
    AND g.level='area' AND g.is_active=true;

  SELECT CASE WHEN left(p.policy_value,1)='{' THEN p.policy_value::jsonb ELSE '{}'::jsonb END
    INTO v_policy
  FROM public.erp_program_policies p
  WHERE p.company_id=NEW.company_id AND p.policy_key='code_generation_registry'
  LIMIT 1;
  v_lengths:=coalesce(v_policy->'geo_segment_lengths','{}'::jsonb);

  SELECT c.country_code INTO v_country_code
  FROM public.erp_countries c
  WHERE c.company_id=NEW.company_id AND c.name_ar='مصر' AND c.is_active=true
  ORDER BY c.created_at LIMIT 1;

  v_geo_digits:=coalesce(length(v_country_code),2)
    +coalesce(nullif(v_lengths->>'governorate','')::integer,2)
    +coalesce(nullif(v_lengths->>'center','')::integer,2)
    +coalesce(nullif(v_lengths->>'area','')::integer,2);

  IF v_geo_code IS NULL OR v_geo_code !~ '^[0-9]+$'
     OR length(v_geo_code)<>v_geo_digits THEN
    RAISE EXCEPTION 'المنطقة المختارة لا تحتوي على كود جغرافي مطابق لأطوال سياسات التكويد (% أرقام)',v_geo_digits;
  END IF;

  SELECT c.prefix,c.digits INTO v_prefix,v_digits
  FROM public.erp_code_policy_config(NEW.company_id,'customer','Cus',2) c;

  IF v_prefix !~ '^[A-Za-z]{1,10}$' OR v_digits<1 OR v_digits>12 THEN
    RAISE EXCEPTION 'إعدادات كود العميل غير صحيحة';
  END IF;

  v_lock:=NEW.company_id::text||':customer:'||NEW.geo_area_id::text;
  PERFORM pg_advisory_xact_lock(hashtextextended(v_lock,0));

  SELECT coalesce(max(substring(p.party_code from (length(v_prefix||v_geo_code)+1))::bigint),0)
    INTO v_max
  FROM public.erp_parties p
  WHERE p.company_id=NEW.company_id
    AND p.party_kind='customer'
    AND p.geo_area_id=NEW.geo_area_id
    AND p.party_code ~ ('^'||v_prefix||v_geo_code||'[0-9]{'||v_digits||'}$');

  IF coalesce(v_max,0)+1>=power(10::numeric,v_digits) THEN
    RAISE EXCEPTION 'انتهت خانات تسلسل العملاء داخل هذه المنطقة؛ زد عدد الخانات من سياسات التكويد';
  END IF;

  NEW.party_code:=v_prefix||v_geo_code||lpad((coalesce(v_max,0)+1)::text,v_digits,'0');
  RETURN NEW;
END;
$function$;

REVOKE ALL ON FUNCTION public.erp_assign_item_hierarchical_code() FROM PUBLIC,anon,authenticated;
REVOKE ALL ON FUNCTION public.erp_assign_geo_hierarchical_code() FROM PUBLIC,anon,authenticated;
REVOKE ALL ON FUNCTION public.erp_assign_customer_geo_code() FROM PUBLIC,anon,authenticated;

-- The 880 existing category codes and all 6,164 geographic codes already
-- match the saved 2/2/2 policy. Preserve those identifiers and all references.
DO $validate$
BEGIN
  IF EXISTS (
    SELECT 1 FROM public.erp_item_categories c
    WHERE c.category_code !~ '^Cat[0-9]{2}([0-9]{2}){0,2}$'
  ) THEN
    RAISE EXCEPTION 'توجد فئات لا تطابق سياسة Cat؛ أوقف الترحيل للمراجعة قبل إعادة التكويد';
  END IF;
  IF EXISTS (
    SELECT 1 FROM public.erp_geographic_data g
    WHERE (g.level='governorate' AND g.hierarchical_code !~ '^[0-9]{4}$')
       OR (g.level='district' AND g.hierarchical_code !~ '^[0-9]{6}$')
       OR (g.level='area' AND g.hierarchical_code !~ '^[0-9]{8}$')
  ) THEN
    RAISE EXCEPTION 'توجد أكواد جغرافية لا تطابق أطوال السياسة الحالية؛ أوقف الترحيل للمراجعة';
  END IF;
END;
$validate$;

-- Resolve the existing item brand from its explicit name first, then its item
-- name. Unmatched items are assigned the reserved Bra000 record.
WITH resolved AS (
  SELECT i.id,
    coalesce(
      (
        SELECT b.id
        FROM public.erp_brands b
        WHERE b.company_id=i.company_id
          AND b.brand_name<>'بدون علامة تجارية'
          AND (
            (nullif(btrim(coalesce(i.brand_name,'')),'') IS NOT NULL
              AND lower(btrim(b.brand_name))=lower(btrim(i.brand_name)))
            OR (nullif(btrim(coalesce(i.brand_name,'')),'') IS NULL
              AND i.item_name ILIKE '%'||b.brand_name||'%')
          )
        ORDER BY
          CASE WHEN lower(btrim(coalesce(i.brand_name,'')))=lower(btrim(b.brand_name)) THEN 0 ELSE 1 END,
          length(b.brand_name) DESC
        LIMIT 1
      ),
      (
        SELECT b.id FROM public.erp_brands b
        WHERE b.company_id=i.company_id AND b.brand_code='Bra000'
        LIMIT 1
      )
    ) AS brand_id
  FROM public.erp_items i
)
UPDATE public.erp_items i
SET brand_id=r.brand_id
FROM resolved r
WHERE i.id=r.id
  AND r.brand_id IS NOT NULL
  AND i.brand_id IS DISTINCT FROM r.brand_id;

COMMIT;