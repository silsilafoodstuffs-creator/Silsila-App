-- Keep direct-delivery authorization compatible with old menu keys while new menus use canonical labels.
begin;
do $$
declare v_def text;
begin
  v_def := pg_get_functiondef('public.erp_guard_sales_direct_delivery()'::regprocedure);
  v_def := replace(v_def, 'and p.menu_key = ''المبيعات والعملاء::حركات::إذن التسليم''',
    'and p.menu_key in (''مبيعات::حركات::إذن التسليم'', ''المبيعات والعملاء::حركات::إذن التسليم'')');
  if position('and p.menu_key in (''مبيعات::حركات::إذن التسليم''' in v_def) = 0 then
    raise exception 'Failed to update delivery permission key compatibility';
  end if;
  execute v_def;
end $$;
commit;
