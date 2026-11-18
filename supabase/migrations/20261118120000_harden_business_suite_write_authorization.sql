-- Harden ERP Business Suite write authorization at the database boundary.
-- The generic save RPC previously checked authentication but not company role.
-- The atomic simple-record RPC also treated mere company membership as write permission.
DO $migration$
DECLARE
  v_def text;
  v_old text;
  v_new text;
  v_count integer;
BEGIN
  v_def := pg_get_functiondef('public.erp_save_business_suite_record(jsonb,jsonb)'::regprocedure);
  v_old := '  v_company_id := NULLIF(p_parent->>''company_id'', '''')::uuid;';
  v_new := v_old || E'\n\n  IF v_company_id IS NULL OR NOT public.erp_user_has_company_role(v_company_id, ARRAY[''owner'',''admin'',''manager'']::text[]) THEN\n    RAISE EXCEPTION ''لا تملك صلاحية إنشاء أو تعديل سجلات هذه الشركة'' USING ERRCODE = ''42501'';\n  END IF;';
  v_count := (length(v_def) - length(replace(v_def, v_old, ''))) / length(v_old);
  IF v_count <> 1 THEN
    RAISE EXCEPTION 'Expected exactly one company-id assignment in erp_save_business_suite_record; found %', v_count;
  END IF;
  EXECUTE replace(v_def, v_old, v_new);

  v_def := pg_get_functiondef('public.erp_save_business_suite_simple_record_atomic(uuid,jsonb,jsonb)'::regprocedure);
  v_old := E'  if not (\n    public.erp_user_has_company_role(v_company_id,array[''owner'',''admin'',''manager'']::text[])\n    or exists (\n      select 1 from public.erp_company_member_profiles p\n      where p.company_id=v_company_id and p.user_id=v_user_id\n    )\n  ) then';
  v_new := E'  if not public.erp_user_has_company_role(v_company_id,array[''owner'',''admin'',''manager'']::text[]) then';
  v_count := (length(v_def) - length(replace(v_def, v_old, ''))) / length(v_old);
  IF v_count <> 1 THEN
    RAISE EXCEPTION 'Expected exactly one broad membership authorization block in atomic simple save; found %', v_count;
  END IF;
  EXECUTE replace(v_def, v_old, v_new);
END
$migration$;

-- Keep the database as the authority: callers may authenticate, but cannot
-- write records for a company unless their effective company role permits it.
