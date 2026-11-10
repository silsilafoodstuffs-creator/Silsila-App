-- Use the maximum existing sibling suffix for category sequencing (not row count),
-- and regenerate a customer code if the area is unchanged but its code is blank.
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
    SELECT coalesce(max(right(c.category_code,v_segment_digits)::integer),0)+1 INTO v_rank
    FROM public.erp_item_categories c
    WHERE c.company_id=NEW.company_id
      AND c.parent_id IS NOT DISTINCT FROM NEW.parent_id
      AND c.id IS DISTINCT FROM NEW.id
      AND left(c.category_code,length(v_prefix||v_parent_digits))=v_prefix||v_parent_digits
      AND length(c.category_code)=length(v_prefix||v_parent_digits)+v_segment_digits
      AND substring(c.category_code from length(v_prefix||v_parent_digits)+1) ~ '^[0-9]+';

    IF v_rank>power(10::numeric,v_segment_digits)-1 THEN
      RAISE EXCEPTION 'عدد الفئات التابعة تجاوز سعة التكويد المحددة (% خانات)',v_segment_digits;
    END IF;

    NEW.category_code:=v_prefix||v_parent_digits||lpad(v_rank::text,v_segment_digits,'0');
  ELSIF NEW.category_code !~ ('^'||v_prefix||'[0-9]{'||v_expected_digits||'}$') THEN
    RAISE EXCEPTION 'كود الفئة يجب أن يطابق سياسة % وعدد أرقام المستوى %',v_prefix,v_expected_digits;
  END IF;

  RETURN NEW;
END;
$function$;);

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
  v_area_id uuid;
  v_max bigint;
  v_lock text;
BEGIN
  IF coalesce(NEW.party_kind,'')<>'customer' THEN
    RETURN NEW;
  END IF;

  IF TG_OP='UPDATE' THEN
    IF NEW.geographic_area_id IS NOT DISTINCT FROM OLD.geographic_area_id
       AND nullif(NEW.party_code,'') IS NOT NULL THEN
      RETURN NEW;
    END IF;
  ELSIF nullif(NEW.party_code,'') IS NOT NULL THEN
    RETURN NEW;
  END IF;

  v_area_id:=NEW.geographic_area_id;
  IF v_area_id IS NULL THEN
    RAISE EXCEPTION 'اختيار المنطقة مطلوب لتوليد كود العميل المرتبط بالتقسيم الجغرافي';
  END IF;

  SELECT g.hierarchical_code INTO v_geo_code
  FROM public.erp_geographic_data g
  WHERE g.id=v_area_id
    AND g.company_id=NEW.company_id
    AND g.level='area'
    AND g.is_active=true;

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

  v_lock:=NEW.company_id::text||':customer:'||v_area_id::text;
  PERFORM pg_advisory_xact_lock(hashtextextended(v_lock,0));

  SELECT coalesce(max(substring(p.party_code from (length(v_prefix||v_geo_code)+1))::bigint),0)
    INTO v_max
  FROM public.erp_parties p
  WHERE p.company_id=NEW.company_id
    AND p.party_kind='customer'
    AND p.geographic_area_id=v_area_id
    AND p.id IS DISTINCT FROM NEW.id
    AND p.party_code ~ ('^'||v_prefix||v_geo_code||'[0-9]{'||v_digits||'}$');

  IF coalesce(v_max,0)+1>=power(10::numeric,v_digits) THEN
    RAISE EXCEPTION 'انتهت خانات تسلسل العملاء داخل هذه المنطقة؛ زد عدد الخانات من سياسات التكويد';
  END IF;

  NEW.party_code:=v_prefix||v_geo_code||lpad((coalesce(v_max,0)+1)::text,v_digits,'0');
  RETURN NEW;
END;
$function$;

REVOKE ALL ON FUNCTION public.erp_assign_customer_geo_code() FROM PUBLIC,anon,authenticated;;

    IF v_rank>power(10::numeric,v_segment_digits)-1 THEN
      RAISE EXCEPTION 'عدد الفئات التابعة تجاوز سعة التكويد المحددة (% خانات)',v_segment_digits;
    END IF;

    NEW.category_code:=v_prefix||v_parent_digits||lpad(v_rank::text,v_segment_digits,'0');
  ELSIF NEW.category_code !~ ('^'||v_prefix||'[0-9]{'||v_expected_digits||'}$') THEN
    RAISE EXCEPTION 'كود الفئة يجب أن يطابق سياسة % وعدد أرقام المستوى %',v_prefix,v_expected_digits;
  END IF;

  RETURN NEW;
END;
$function$;);

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
  v_area_id uuid;
  v_max bigint;
  v_lock text;
BEGIN
  IF coalesce(NEW.party_kind,'')<>'customer' THEN
    RETURN NEW;
  END IF;

  IF TG_OP='UPDATE' THEN
    IF NEW.geographic_area_id IS NOT DISTINCT FROM OLD.geographic_area_id
       AND nullif(NEW.party_code,'') IS NOT NULL THEN
      RETURN NEW;
    END IF;
  ELSIF nullif(NEW.party_code,'') IS NOT NULL THEN
    RETURN NEW;
  END IF;

  v_area_id:=NEW.geographic_area_id;
  IF v_area_id IS NULL THEN
    RAISE EXCEPTION 'اختيار المنطقة مطلوب لتوليد كود العميل المرتبط بالتقسيم الجغرافي';
  END IF;

  SELECT g.hierarchical_code INTO v_geo_code
  FROM public.erp_geographic_data g
  WHERE g.id=v_area_id
    AND g.company_id=NEW.company_id
    AND g.level='area'
    AND g.is_active=true;

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

  v_lock:=NEW.company_id::text||':customer:'||v_area_id::text;
  PERFORM pg_advisory_xact_lock(hashtextextended(v_lock,0));

  SELECT coalesce(max(substring(p.party_code from (length(v_prefix||v_geo_code)+1))::bigint),0)
    INTO v_max
  FROM public.erp_parties p
  WHERE p.company_id=NEW.company_id
    AND p.party_kind='customer'
    AND p.geographic_area_id=v_area_id
    AND p.id IS DISTINCT FROM NEW.id
    AND p.party_code ~ ('^'||v_prefix||v_geo_code||'[0-9]{'||v_digits||'}$');

  IF coalesce(v_max,0)+1>=power(10::numeric,v_digits) THEN
    RAISE EXCEPTION 'انتهت خانات تسلسل العملاء داخل هذه المنطقة؛ زد عدد الخانات من سياسات التكويد';
  END IF;

  NEW.party_code:=v_prefix||v_geo_code||lpad((coalesce(v_max,0)+1)::text,v_digits,'0');
  RETURN NEW;
END;
$function$;

REVOKE ALL ON FUNCTION public.erp_assign_customer_geo_code() FROM PUBLIC,anon,authenticated;