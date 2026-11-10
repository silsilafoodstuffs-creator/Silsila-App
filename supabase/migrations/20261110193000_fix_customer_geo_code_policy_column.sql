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
    IF NEW.geographic_area_id IS NOT DISTINCT FROM OLD.geographic_area_id THEN
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