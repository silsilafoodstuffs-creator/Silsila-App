-- Keep the movement-audit UI terminology aligned with the canonical item categories table.
-- This rewrites only user-visible labels and stable issue identifiers in the existing function.
begin;
do $$
declare
  v_def text;
begin
  v_def := pg_get_functiondef('public.erp_run_movement_audit(uuid,date,date,text)'::regprocedure);
  v_def := replace(v_def, 'مجموعات الأصناف', 'فئات الأصناف');
  v_def := replace(v_def, 'item-group:', 'item-category:');
  v_def := replace(v_def, 'مجموعات', 'فئات');
  if position('مجموعات الأصناف' in v_def) > 0 then
    raise exception 'Legacy item-group label remains in erp_run_movement_audit';
  end if;
  execute v_def;
end $$;
commit;
