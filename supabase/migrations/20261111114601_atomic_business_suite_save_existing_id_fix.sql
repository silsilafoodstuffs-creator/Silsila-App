
DO $migration$
DECLARE
  v_definition text;
  v_old text := '  v_table := NULLIF(BTRIM(p_plan->>''table''), '''');';
  v_new text := '  v_table := NULLIF(BTRIM(p_plan->>''table''), '''');' || E'\n'
    || '  v_existing_operational_id := NULLIF(p_plan->>''id'', '''')::uuid;';
BEGIN
  SELECT pg_get_functiondef(p.oid)
    INTO v_definition
  FROM pg_proc p
  JOIN pg_namespace n ON n.oid=p.pronamespace
  WHERE n.nspname='public'
    AND p.proname='erp_save_business_suite_record'
    AND pg_get_function_identity_arguments(p.oid)='p_parent jsonb, p_plan jsonb';

  IF v_definition IS NULL THEN
    RAISE EXCEPTION 'إجراء الحفظ الذري غير موجود؛ أوقف التصحيح';
  END IF;

  IF position('v_existing_operational_id := NULLIF' in v_definition) > 0 THEN
    RETURN;
  END IF;

  IF position(v_old in v_definition) = 0 THEN
    RAISE EXCEPTION 'لم يتم العثور على موضع آمن لإضافة معرّف السجل التشغيلي';
  END IF;

  v_definition := replace(v_definition, v_old, v_new);
  EXECUTE v_definition;

  REVOKE ALL ON FUNCTION public.erp_save_business_suite_record(jsonb,jsonb) FROM PUBLIC;
  REVOKE ALL ON FUNCTION public.erp_save_business_suite_record(jsonb,jsonb) FROM anon;
  GRANT EXECUTE ON FUNCTION public.erp_save_business_suite_record(jsonb,jsonb) TO authenticated;
END;
$migration$;
