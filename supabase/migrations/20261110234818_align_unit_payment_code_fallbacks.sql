BEGIN;

DO $migration$
DECLARE
  v_definition text;
  v_updated text;
BEGIN
  v_definition := pg_get_functiondef('public.erp_assign_central_code()'::regprocedure);
  v_updated := replace(v_definition, 'when ''unit'' then ''Unt''', 'when ''unit'' then ''UNT''');
  v_updated := replace(v_updated, 'when ''payment_method'' then ''Pmt''', 'when ''payment_method'' then ''PAY''');
  v_updated := replace(v_updated, 'when ''customer'' then 4', 'when ''customer'' then 4 when ''unit'' then 4 when ''payment_method'' then 4');
  IF v_updated = v_definition
     OR position('when ''unit'' then ''UNT''' in v_updated)=0
     OR position('when ''payment_method'' then ''PAY''' in v_updated)=0
     OR position('when ''unit'' then 4' in v_updated)=0
     OR position('when ''payment_method'' then 4' in v_updated)=0 THEN
    RAISE EXCEPTION 'Could not align central generator unit/payment fallbacks';
  END IF;
  EXECUTE v_updated;

  v_definition := pg_get_functiondef('public.erp_preview_next_central_code(uuid,text)'::regprocedure);
  v_updated := replace(v_definition,
    'when ''unit'' then v_table := ''erp_item_unit_catalog''; v_column := ''unit_code''; v_prefix := ''Unt'';',
    'when ''unit'' then v_table := ''erp_item_unit_catalog''; v_column := ''unit_code''; v_prefix := ''UNT'';');
  v_updated := replace(v_updated,
    'when ''payment_method'' then v_table := ''erp_payment_methods''; v_column := ''payment_method_code''; v_prefix := ''Pmt'';',
    'when ''payment_method'' then v_table := ''erp_payment_methods''; v_column := ''payment_method_code''; v_prefix := ''PAY'';');
  v_updated := replace(v_updated,
    'when ''permission_template'' then 5 else 5 end',
    'when ''permission_template'' then 5 when ''unit'' then 4 when ''payment_method'' then 4 else 5 end');
  IF v_updated = v_definition
     OR position('v_prefix := ''UNT''' in v_updated)=0
     OR position('v_prefix := ''PAY''' in v_updated)=0
     OR position('when ''unit'' then 4' in v_updated)=0
     OR position('when ''payment_method'' then 4' in v_updated)=0 THEN
    RAISE EXCEPTION 'Could not align central code preview unit/payment fallbacks';
  END IF;
  EXECUTE v_updated;
END;
$migration$;

COMMIT;
