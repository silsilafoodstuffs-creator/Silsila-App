-- Remove the obsolete item-group selection alias from selective data clearing.
-- The only supported UI label and data table are item categories.
begin;
do $$
declare
  v_def text;
begin
  v_def := pg_get_functiondef('public.erp_prepare_selective_data_clear(uuid,text[])'::regprocedure);
  v_def := replace(v_def, '(''مجموعات الأصناف'',''erp_item_categories''),', '');
  v_def := replace(v_def, 'مجموعات الأصناف', 'فئات الأصناف');
  v_def := replace(v_def, '(''فئات الأصناف'',''erp_item_categories''),(''فئات الأصناف'',''erp_item_categories''),',
                          '(''فئات الأصناف'',''erp_item_categories''),');
  if position('مجموعات الأصناف' in v_def) > 0 then
    raise exception 'Legacy item-group label remains in erp_prepare_selective_data_clear';
  end if;
  execute v_def;
end $$;
commit;
