CREATE OR REPLACE FUNCTION public.erp_code_policy_lock_status(p_company_id uuid)
RETURNS text[]
LANGUAGE sql
SET search_path TO ''
AS $function$
  SELECT CASE
    WHEN EXISTS (
      SELECT 1 FROM public.erp_brands b
      WHERE b.company_id = p_company_id
        AND nullif(b.brand_code, '') IS NOT NULL
    )
    THEN array_append(private.erp_code_policy_lock_status(p_company_id), 'brand_code')
    ELSE private.erp_code_policy_lock_status(p_company_id)
  END;
$function$;
