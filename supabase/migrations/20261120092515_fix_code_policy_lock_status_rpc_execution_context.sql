-- Fix the code-policy lock RPC after its implementation was moved to the private schema.
-- The public invoker wrapper could execute the private function but authenticated callers
-- intentionally have no USAGE on the private schema, producing PostgREST 403 / 42501.
-- Keep the private schema unexposed and execute the wrapper as its owner, with an explicit
-- authenticated active-company-membership guard before reading any policy lock state.

CREATE OR REPLACE FUNCTION public.erp_code_policy_lock_status(p_company_id uuid)
RETURNS text[]
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO ''
AS $function$
DECLARE
  v_locked text[];
BEGIN
  IF auth.uid() IS NULL OR NOT public.erp_user_can_access_company(p_company_id) THEN
    RAISE EXCEPTION 'غير مصرح بقراءة حالة سياسات التكويد لهذه الشركة'
      USING ERRCODE = '42501';
  END IF;

  v_locked := private.erp_code_policy_lock_status(p_company_id);

  IF EXISTS (
    SELECT 1 FROM public.erp_brands b
    WHERE b.company_id = p_company_id AND nullif(b.brand_code, '') IS NOT NULL
  ) THEN
    v_locked := array_append(v_locked, 'brand_code');
  END IF;

  IF EXISTS (
    SELECT 1 FROM public.erp_brand_groups g
    WHERE g.company_id = p_company_id AND nullif(g.group_code, '') IS NOT NULL
  ) THEN
    v_locked := array_append(v_locked, 'code_type.brand_group');
  END IF;

  RETURN v_locked;
END;
$function$;

REVOKE ALL ON FUNCTION public.erp_code_policy_lock_status(uuid) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.erp_code_policy_lock_status(uuid) TO authenticated;
