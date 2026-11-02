-- Tighten stocktake and manual-adjustment RPC authorization.
-- A company membership alone is not sufficient to create, edit, or post
-- inventory adjustments. Match the inventory movement role allow-list.
DO $migration$
DECLARE
  v_definition text;
BEGIN
  v_definition := pg_get_functiondef('public.erp_create_manual_stock_adjustment(uuid,uuid,text)'::regprocedure);
  IF position('not public.erp_user_can_access_company(p_company_id)' in v_definition) = 0 THEN
    RAISE EXCEPTION 'Unexpected guard in erp_create_manual_stock_adjustment; aborting';
  END IF;
  v_definition := replace(v_definition,
    'not public.erp_user_can_access_company(p_company_id)',
    'not public.erp_user_has_company_role(p_company_id, ARRAY[''owner'',''admin'',''manager'',''operator'',''accountant'']::text[])');
  EXECUTE v_definition;

  v_definition := pg_get_functiondef('public.erp_create_physical_stocktake(uuid,uuid,text,text,text)'::regprocedure);
  IF position('not public.erp_user_can_access_company(p_company_id)' in v_definition) = 0 THEN
    RAISE EXCEPTION 'Unexpected guard in erp_create_physical_stocktake; aborting';
  END IF;
  v_definition := replace(v_definition,
    'not public.erp_user_can_access_company(p_company_id)',
    'not public.erp_user_has_company_role(p_company_id, ARRAY[''owner'',''admin'',''manager'',''operator'',''accountant'']::text[])');
  EXECUTE v_definition;

  v_definition := pg_get_functiondef('public.erp_save_physical_stocktake_counts(uuid,jsonb)'::regprocedure);
  IF position('not public.erp_user_can_access_company(v_doc.company_id)' in v_definition) = 0 THEN
    RAISE EXCEPTION 'Unexpected guard in erp_save_physical_stocktake_counts; aborting';
  END IF;
  v_definition := replace(v_definition,
    'not public.erp_user_can_access_company(v_doc.company_id)',
    'not public.erp_user_has_company_role(v_doc.company_id, ARRAY[''owner'',''admin'',''manager'',''operator'',''accountant'']::text[])');
  EXECUTE v_definition;

  v_definition := pg_get_functiondef('public.erp_post_physical_stocktake(uuid,text,uuid)'::regprocedure);
  IF position('not public.erp_user_can_access_company(v_doc.company_id)' in v_definition) = 0 THEN
    RAISE EXCEPTION 'Unexpected guard in erp_post_physical_stocktake; aborting';
  END IF;
  v_definition := replace(v_definition,
    'not public.erp_user_can_access_company(v_doc.company_id)',
    'not public.erp_user_has_company_role(v_doc.company_id, ARRAY[''owner'',''admin'',''manager'',''operator'',''accountant'']::text[])');
  EXECUTE v_definition;
END
$migration$;
