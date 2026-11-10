-- Persist independent segment lengths derived from the previous cumulative values.
UPDATE public.erp_program_policies p
SET policy_value = (
  p.policy_value::jsonb ||
  jsonb_build_object(
    'geo_segment_lengths',
    jsonb_build_object(
      'country', 2,
      'governorate', greatest(1, coalesce(nullif(p.policy_value::jsonb->'geo_segments'->>'governorate','')::integer,4) - 2),
      'center', greatest(1, coalesce(nullif(p.policy_value::jsonb->'geo_segments'->>'center','')::integer,6) - coalesce(nullif(p.policy_value::jsonb->'geo_segments'->>'governorate','')::integer,4)),
      'area', greatest(1, coalesce(nullif(p.policy_value::jsonb->'geo_segments'->>'area','')::integer,8) - coalesce(nullif(p.policy_value::jsonb->'geo_segments'->>'center','')::integer,6))
    )
  )
)::text
WHERE p.policy_key='code_generation_registry'
  AND left(p.policy_value,1)='{';

-- The configured Rig prefix belongs to the area code. Governorate and
-- district path segments remain numeric so the customer code can inherit digits only.
UPDATE public.erp_geographic_data g
SET hierarchical_code = coalesce(nullif(p.policy_value::jsonb->>'geo_prefix',''),'Rig') || g.hierarchical_code
FROM public.erp_program_policies p
WHERE p.company_id=g.company_id
  AND p.policy_key='code_generation_registry'
  AND g.level='area'
  AND g.hierarchical_code IS NOT NULL
  AND left(g.hierarchical_code,length(coalesce(nullif(p.policy_value::jsonb->>'geo_prefix',''),'Rig')))
      <> coalesce(nullif(p.policy_value::jsonb->>'geo_prefix',''),'Rig');

CREATE OR REPLACE FUNCTION public.erp_assign_geo_hierarchical_code()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO ''
AS $function$
DECLARE
  v_policy jsonb := '{}'::jsonb;
  v_lengths jsonb := '{}'::jsonb;
  v_segments jsonb := '{}'::jsonb;
  v_country_code text;
  v_geo_prefix text := 'Rig';
  v_parent_code text;
  v_code_prefix text;
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
  v_segments:=coalesce(v_policy->'geo_segments','{}'::jsonb);
  v_geo_prefix:=coalesce(nullif(v_policy->>'geo_prefix',''),'Rig');

  SELECT c.country_code INTO v_country_code
  FROM public.erp_countries c
  WHERE c.company_id=NEW.company_id AND c.name_ar='مصر' AND c.is_active=true
  ORDER BY c.created_at LIMIT 1;

  IF v_country_code IS NULL OR length(v_country_code)<>2 OR v_country_code !~ '^[0-9]+' THEN
    RAISE EXCEPTION 'يجب تسجيل كود مصر المكون من رقمين في تبويب بيانات الدول أولًا';
  END IF;
  IF length(v_geo_prefix)<1 OR length(v_geo_prefix)>10
     OR v_geo_prefix !~ '^[A-Za-z]+' OR v_geo_prefix ~ '[^A-Za-z]' THEN
    RAISE EXCEPTION 'بادئة المنطقة في سياسات التكويد غير صحيحة';
  END IF;

  IF v_lengths='{}'::jsonb THEN
    v_lengths:=jsonb_build_object(
      'governorate',coalesce(nullif(v_segments->>'governorate','')::integer - length(v_country_code),2),
      'center',coalesce(nullif(v_segments->>'center','')::integer - nullif(v_segments->>'governorate','')::integer,2),
      'area',coalesce(nullif(v_segments->>'area','')::integer - nullif(v_segments->>'center','')::integer,2)
    );
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

    SELECT coalesce(max(substring(g.hierarchical_code from length(v_country_code)+1)::bigint),0)+1
      INTO v_next
    FROM public.erp_geographic_data g
    WHERE g.company_id=NEW.company_id
      AND g.level='governorate'
      AND left(g.hierarchical_code,length(v_country_code))=v_country_code
      AND length(g.hierarchical_code)=length(v_country_code)+v_segment_digits
      AND substring(g.hierarchical_code from length(v_country_code)+1) ~ '^[0-9]+';

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
    WHERE g.id=NEW.parent_id
      AND g.company_id=NEW.company_id
      AND g.level=CASE WHEN NEW.level='district' THEN 'governorate' ELSE 'district' END;

    IF v_parent_code IS NULL OR v_parent_code !~ '^[0-9]+' THEN
      RAISE EXCEPTION 'التسلسل الجغرافي غير صحيح: اربط كل مستوى بأبيه الصحيح';
    END IF;

    v_segment_digits:=CASE WHEN NEW.level='district'
      THEN coalesce(nullif(v_lengths->>'center','')::integer,2)
      ELSE coalesce(nullif(v_lengths->>'area','')::integer,2) END;

    IF v_segment_digits NOT BETWEEN 1 AND 6 THEN
      RAISE EXCEPTION 'عدد خانات المستوى الجغرافي يجب أن يكون من 1 إلى 6';
    END IF;

    v_code_prefix:=CASE WHEN NEW.level='area' THEN v_geo_prefix||v_parent_code ELSE v_parent_code END;
    v_lock:=NEW.company_id::text||':'||NEW.parent_id::text||':'||NEW.level;
    PERFORM pg_advisory_xact_lock(hashtextextended(v_lock,0));

    SELECT coalesce(max(substring(g.hierarchical_code from length(v_code_prefix)+1)::bigint),0)+1
      INTO v_next
    FROM public.erp_geographic_data g
    WHERE g.company_id=NEW.company_id
      AND g.parent_id=NEW.parent_id
      AND g.level=NEW.level
      AND left(g.hierarchical_code,length(v_code_prefix))=v_code_prefix
      AND length(g.hierarchical_code)=length(v_code_prefix)+v_segment_digits
      AND substring(g.hierarchical_code from length(v_code_prefix)+1) ~ '^[0-9]+';

    IF v_next>power(10::numeric,v_segment_digits)-1 THEN
      RAISE EXCEPTION 'تم استنفاد الأكواد التابعة لهذا المستوى وفق سياسة التكويد';
    END IF;

    NEW.hierarchical_code:=v_code_prefix||lpad(v_next::text,v_segment_digits,'0');
  ELSE
    RAISE EXCEPTION 'مستوى جغرافي غير مدعوم: %',NEW.level;
  END IF;

  RETURN NEW;
END;
$function$;

REVOKE ALL ON FUNCTION public.erp_assign_geo_hierarchical_code() FROM PUBLIC,anon,authenticated;

CREATE OR REPLACE FUNCTION public.erp_assign_customer_geo_code()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO ''
AS $function$
DECLARE
  v_geo_hierarchical_code text;
  v_geo_code text;
  v_geo_prefix text := 'Rig';
  v_country_code text;
  v_policy jsonb := '{}'::jsonb;
  v_lengths jsonb := '{}'::jsonb;
  v_segments jsonb := '{}'::jsonb;
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

  SELECT CASE WHEN left(p.policy_value,1)='{' THEN p.policy_value::jsonb ELSE '{}'::jsonb END
    INTO v_policy
  FROM public.erp_program_policies p
  WHERE p.company_id=NEW.company_id AND p.policy_key='code_generation_registry'
  LIMIT 1;
  v_geo_prefix:=coalesce(nullif(v_policy->>'geo_prefix',''),'Rig');
  v_lengths:=coalesce(v_policy->'geo_segment_lengths','{}'::jsonb);
  v_segments:=coalesce(v_policy->'geo_segments','{}'::jsonb);

  SELECT c.country_code INTO v_country_code
  FROM public.erp_countries c
  WHERE c.company_id=NEW.company_id AND c.name_ar='مصر' AND c.is_active=true
  ORDER BY c.created_at LIMIT 1;

  IF v_country_code IS NULL OR length(v_country_code)<>2 OR v_country_code !~ '^[0-9]+' THEN
    RAISE EXCEPTION 'كود مصر يجب أن يكون رقمين لتوليد كود العميل';
  END IF;

  IF v_lengths='{}'::jsonb THEN
    v_lengths:=jsonb_build_object(
      'governorate',coalesce(nullif(v_segments->>'governorate','')::integer - length(v_country_code),2),
      'center',coalesce(nullif(v_segments->>'center','')::integer - nullif(v_segments->>'governorate','')::integer,2),
      'area',coalesce(nullif(v_segments->>'area','')::integer - nullif(v_segments->>'center','')::integer,2)
    );
  END IF;

  v_geo_digits:=length(v_country_code)
    +coalesce(nullif(v_lengths->>'governorate','')::integer,2)
    +coalesce(nullif(v_lengths->>'center','')::integer,2)
    +coalesce(nullif(v_lengths->>'area','')::integer,2);

  SELECT g.hierarchical_code INTO v_geo_hierarchical_code
  FROM public.erp_geographic_data g
  WHERE g.id=v_area_id
    AND g.company_id=NEW.company_id
    AND g.level='area'
    AND g.is_active=true;

  v_geo_code:=regexp_replace(coalesce(v_geo_hierarchical_code,''),'[^0-9]','','g');
  IF v_geo_hierarchical_code IS NULL
     OR left(v_geo_hierarchical_code,length(v_geo_prefix))<>v_geo_prefix
     OR length(v_geo_code)<>v_geo_digits THEN
    RAISE EXCEPTION 'المنطقة المختارة لا تحتوي على كود Rig مطابق لأطوال سياسات التكويد (% أرقام)',v_geo_digits;
  END IF;

  SELECT c.prefix,c.digits INTO v_prefix,v_digits
  FROM public.erp_code_policy_config(NEW.company_id,'customer','Cus',2) c;

  IF length(v_prefix)<1 OR length(v_prefix)>10 OR v_prefix !~ '^[A-Za-z]+'
     OR v_prefix ~ '[^A-Za-z]' OR v_digits<1 OR v_digits>12 THEN
    RAISE EXCEPTION 'إعدادات كود العميل غير صحيحة';
  END IF;

  v_lock:=NEW.company_id::text||':customer:'||v_area_id::text;
  PERFORM pg_advisory_xact_lock(hashtextextended(v_lock,0));

  SELECT coalesce(max(substring(p.party_code from length(v_prefix||v_geo_code)+1)::bigint),0)
    INTO v_max
  FROM public.erp_parties p
  WHERE p.company_id=NEW.company_id
    AND p.party_kind='customer'
    AND p.geographic_area_id=v_area_id
    AND p.id IS DISTINCT FROM NEW.id
    AND left(p.party_code,length(v_prefix||v_geo_code))=v_prefix||v_geo_code
    AND length(p.party_code)=length(v_prefix||v_geo_code)+v_digits
    AND substring(p.party_code from length(v_prefix||v_geo_code)+1) ~ '^[0-9]+';

  IF coalesce(v_max,0)+1>=power(10::numeric,v_digits) THEN
    RAISE EXCEPTION 'انتهت خانات تسلسل العملاء داخل هذه المنطقة؛ زد عدد الخانات من سياسات التكويد';
  END IF;

  NEW.party_code:=v_prefix||v_geo_code||lpad((coalesce(v_max,0)+1)::text,v_digits,'0');
  RETURN NEW;
END;
$function$;

REVOKE ALL ON FUNCTION public.erp_assign_customer_geo_code() FROM PUBLIC,anon,authenticated;

CREATE OR REPLACE FUNCTION public.erp_preview_next_customer_geo_code(p_company_id uuid,p_geo_area_id uuid)
RETURNS text
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO ''
AS $function$
DECLARE
  v_geo_hierarchical_code text;
  v_geo_code text;
  v_geo_prefix text := 'Rig';
  v_country_code text;
  v_policy jsonb := '{}'::jsonb;
  v_lengths jsonb := '{}'::jsonb;
  v_segments jsonb := '{}'::jsonb;
  v_geo_digits integer;
  v_prefix text := 'Cus';
  v_digits integer := 2;
  v_max bigint;
BEGIN
  IF auth.uid() IS NULL OR NOT public.erp_user_can_access_company(p_company_id) THEN
    RAISE EXCEPTION 'غير مصرح بمعاينة أكواد هذه الشركة';
  END IF;

  SELECT CASE WHEN left(p.policy_value,1)='{' THEN p.policy_value::jsonb ELSE '{}'::jsonb END
    INTO v_policy
  FROM public.erp_program_policies p
  WHERE p.company_id=p_company_id AND p.policy_key='code_generation_registry'
  LIMIT 1;
  v_geo_prefix:=coalesce(nullif(v_policy->>'geo_prefix',''),'Rig');
  v_lengths:=coalesce(v_policy->'geo_segment_lengths','{}'::jsonb);
  v_segments:=coalesce(v_policy->'geo_segments','{}'::jsonb);

  SELECT c.country_code INTO v_country_code
  FROM public.erp_countries c
  WHERE c.company_id=p_company_id AND c.name_ar='مصر' AND c.is_active=true
  ORDER BY c.created_at LIMIT 1;

  IF v_country_code IS NULL OR length(v_country_code)<>2 OR v_country_code !~ '^[0-9]+' THEN
    RAISE EXCEPTION 'كود مصر يجب أن يكون رقمين لمعاينة كود العميل';
  END IF;

  IF v_lengths='{}'::jsonb THEN
    v_lengths:=jsonb_build_object(
      'governorate',coalesce(nullif(v_segments->>'governorate','')::integer - length(v_country_code),2),
      'center',coalesce(nullif(v_segments->>'center','')::integer - nullif(v_segments->>'governorate','')::integer,2),
      'area',coalesce(nullif(v_segments->>'area','')::integer - nullif(v_segments->>'center','')::integer,2)
    );
  END IF;

  v_geo_digits:=length(v_country_code)
    +coalesce(nullif(v_lengths->>'governorate','')::integer,2)
    +coalesce(nullif(v_lengths->>'center','')::integer,2)
    +coalesce(nullif(v_lengths->>'area','')::integer,2);

  SELECT g.hierarchical_code INTO v_geo_hierarchical_code
  FROM public.erp_geographic_data g
  WHERE g.id=p_geo_area_id AND g.company_id=p_company_id AND g.level='area' AND g.is_active=true;

  v_geo_code:=regexp_replace(coalesce(v_geo_hierarchical_code,''),'[^0-9]','','g');
  IF v_geo_hierarchical_code IS NULL
     OR left(v_geo_hierarchical_code,length(v_geo_prefix))<>v_geo_prefix
     OR length(v_geo_code)<>v_geo_digits THEN
    RAISE EXCEPTION 'اختر منطقة فعالة لها كود Rig مطابق لأطوال سياسة التكويد';
  END IF;

  SELECT c.prefix,c.digits INTO v_prefix,v_digits
  FROM public.erp_code_policy_config(p_company_id,'customer','Cus',2) c;

  SELECT coalesce(max(substring(p.party_code from length(v_prefix||v_geo_code)+1)::bigint),0)
    INTO v_max
  FROM public.erp_parties p
  WHERE p.company_id=p_company_id
    AND p.party_kind='customer'
    AND p.geographic_area_id=p_geo_area_id
    AND left(p.party_code,length(v_prefix||v_geo_code))=v_prefix||v_geo_code
    AND length(p.party_code)=length(v_prefix||v_geo_code)+v_digits
    AND substring(p.party_code from length(v_prefix||v_geo_code)+1) ~ '^[0-9]+';

  RETURN v_prefix||v_geo_code||lpad((coalesce(v_max,0)+1)::text,v_digits,'0');
END;
$function$;

REVOKE ALL ON FUNCTION public.erp_preview_next_customer_geo_code(uuid,uuid) FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.erp_preview_next_customer_geo_code(uuid,uuid) TO authenticated;

CREATE OR REPLACE FUNCTION public.erp_rebuild_geographic_hierarchical_codes(p_company_id uuid)
RETURNS integer
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO ''
AS $function$
DECLARE
  v_policy jsonb := '{}'::jsonb;
  v_lengths jsonb := '{}'::jsonb;
  v_segments jsonb := '{}'::jsonb;
  v_country_code text;
  v_geo_prefix text := 'Rig';
  v_governorate_digits integer;
  v_center_digits integer;
  v_area_digits integer;
  v_mismatch integer;
  v_total integer := 0;
  v_rows integer := 0;
  v_max_count integer;
BEGIN
  IF auth.uid() IS NULL OR NOT public.erp_user_can_access_company(p_company_id) THEN
    RAISE EXCEPTION 'غير مصرح بإعادة تكويد التقسيم الجغرافي لهذه الشركة';
  END IF;

  SELECT CASE WHEN left(p.policy_value,1)='{' THEN p.policy_value::jsonb ELSE '{}'::jsonb END
    INTO v_policy
  FROM public.erp_program_policies p
  WHERE p.company_id=p_company_id AND p.policy_key='code_generation_registry'
  LIMIT 1;
  v_geo_prefix:=coalesce(nullif(v_policy->>'geo_prefix',''),'Rig');
  v_lengths:=coalesce(v_policy->'geo_segment_lengths','{}'::jsonb);
  v_segments:=coalesce(v_policy->'geo_segments','{}'::jsonb);

  SELECT c.country_code INTO v_country_code
  FROM public.erp_countries c
  WHERE c.company_id=p_company_id AND c.name_ar='مصر' AND c.is_active=true
  ORDER BY c.created_at LIMIT 1;

  IF v_country_code IS NULL OR length(v_country_code)<>2 OR v_country_code !~ '^[0-9]+' THEN
    RAISE EXCEPTION 'كود مصر يجب أن يكون رقمين قبل إعادة تكويد الجغرافيا';
  END IF;
  IF length(v_geo_prefix)<1 OR length(v_geo_prefix)>10 OR v_geo_prefix !~ '^[A-Za-z]+'
     OR v_geo_prefix ~ '[^A-Za-z]' THEN
    RAISE EXCEPTION 'بادئة المنطقة يجب أن تكون حروفًا إنجليزية من 1 إلى 10 حروف';
  END IF;

  IF v_lengths='{}'::jsonb THEN
    v_lengths:=jsonb_build_object(
      'governorate',coalesce(nullif(v_segments->>'governorate','')::integer - length(v_country_code),2),
      'center',coalesce(nullif(v_segments->>'center','')::integer - nullif(v_segments->>'governorate','')::integer,2),
      'area',coalesce(nullif(v_segments->>'area','')::integer - nullif(v_segments->>'center','')::integer,2)
    );
  END IF;
  v_governorate_digits:=coalesce(nullif(v_lengths->>'governorate','')::integer,2);
  v_center_digits:=coalesce(nullif(v_lengths->>'center','')::integer,2);
  v_area_digits:=coalesce(nullif(v_lengths->>'area','')::integer,2);
  IF v_governorate_digits NOT BETWEEN 1 AND 6 OR v_center_digits NOT BETWEEN 1 AND 6 OR v_area_digits NOT BETWEEN 1 AND 6 THEN
    RAISE EXCEPTION 'أطوال أكواد المستويات الجغرافية يجب أن تكون من 1 إلى 6';
  END IF;

  SELECT count(*) INTO v_mismatch
  FROM public.erp_geographic_data g
  LEFT JOIN public.erp_geographic_data p ON p.id=g.parent_id AND p.company_id=g.company_id
  WHERE g.company_id=p_company_id
    AND (
      (g.level='governorate' AND (left(g.hierarchical_code,length(v_country_code))<>v_country_code OR length(g.hierarchical_code)<>length(v_country_code)+v_governorate_digits))
      OR (g.level='district' AND (p.id IS NULL OR left(g.hierarchical_code,length(p.hierarchical_code))<>p.hierarchical_code OR length(g.hierarchical_code)<>length(p.hierarchical_code)+v_center_digits))
      OR (g.level='area' AND (p.id IS NULL OR left(g.hierarchical_code,length(v_geo_prefix||p.hierarchical_code))<>v_geo_prefix||p.hierarchical_code OR length(g.hierarchical_code)<>length(v_geo_prefix||p.hierarchical_code)+v_area_digits))
    );

  IF coalesce(v_mismatch,0)=0 THEN
    RETURN 0;
  END IF;

  SELECT count(*) INTO v_max_count FROM public.erp_geographic_data WHERE company_id=p_company_id AND level='governorate';
  IF v_max_count>power(10::numeric,v_governorate_digits)-1 THEN
    RAISE EXCEPTION 'عدد المحافظات يتجاوز سعة سياسة التكويد الجغرافي';
  END IF;
  SELECT coalesce(max(n),0) INTO v_max_count
  FROM (SELECT count(*) n FROM public.erp_geographic_data WHERE company_id=p_company_id AND level='district' GROUP BY parent_id) x;
  IF v_max_count>power(10::numeric,v_center_digits)-1 THEN
    RAISE EXCEPTION 'عدد المراكز/الأحياء داخل أحد المحافظات يتجاوز سعة سياسة التكويد';
  END IF;
  SELECT coalesce(max(n),0) INTO v_max_count
  FROM (SELECT count(*) n FROM public.erp_geographic_data WHERE company_id=p_company_id AND level='area' GROUP BY parent_id) x;
  IF v_max_count>power(10::numeric,v_area_digits)-1 THEN
    RAISE EXCEPTION 'عدد المناطق داخل أحد المراكز يتجاوز سعة سياسة التكويد';
  END IF;

  WITH ranked AS (
    SELECT g.id,v_country_code||lpad(row_number() over(order by g.hierarchical_code,g.id)::text,v_governorate_digits,'0') new_code
    FROM public.erp_geographic_data g
    WHERE g.company_id=p_company_id AND g.level='governorate'
  )
  UPDATE public.erp_geographic_data g SET hierarchical_code=ranked.new_code
  FROM ranked WHERE g.id=ranked.id;
  GET DIAGNOSTICS v_rows=ROW_COUNT;
  v_total:=v_total+v_rows;

  WITH ranked AS (
    SELECT g.id,p.hierarchical_code||lpad(row_number() over(partition by g.parent_id order by g.hierarchical_code,g.id)::text,v_center_digits,'0') new_code
    FROM public.erp_geographic_data g
    JOIN public.erp_geographic_data p ON p.id=g.parent_id AND p.company_id=g.company_id
    WHERE g.company_id=p_company_id AND g.level='district'
  )
  UPDATE public.erp_geographic_data g SET hierarchical_code=ranked.new_code
  FROM ranked WHERE g.id=ranked.id;
  GET DIAGNOSTICS v_rows=ROW_COUNT;
  v_total:=v_total+v_rows;

  WITH ranked AS (
    SELECT g.id,v_geo_prefix||p.hierarchical_code||lpad(row_number() over(partition by g.parent_id order by g.hierarchical_code,g.id)::text,v_area_digits,'0') new_code
    FROM public.erp_geographic_data g
    JOIN public.erp_geographic_data p ON p.id=g.parent_id AND p.company_id=g.company_id
    WHERE g.company_id=p_company_id AND g.level='area'
  )
  UPDATE public.erp_geographic_data g SET hierarchical_code=ranked.new_code
  FROM ranked WHERE g.id=ranked.id;
  GET DIAGNOSTICS v_rows=ROW_COUNT;
  v_total:=v_total+v_rows;

  UPDATE public.erp_parties
  SET party_code=NULL,geographic_area_id=geographic_area_id
  WHERE company_id=p_company_id AND party_kind='customer' AND geographic_area_id IS NOT NULL;

  RETURN v_total;
END;
$function$;

REVOKE ALL ON FUNCTION public.erp_rebuild_geographic_hierarchical_codes(uuid) FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.erp_rebuild_geographic_hierarchical_codes(uuid) TO authenticated;