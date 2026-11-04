-- Align fallback prefixes with the central-code preview and policy defaults.
-- Existing records and already-issued codes are intentionally left unchanged.
do $migration$
declare
  v_definition text;
  v_pair record;
begin
  select pg_get_functiondef('public.erp_assign_central_code()'::regprocedure)
    into v_definition;

  if v_definition is null then
    raise exception 'تعذر العثور على دالة التكويد المركزي';
  end if;

  for v_pair in
    select * from (values
      ('when ''price_list'' then ''Prc''', 'when ''price_list'' then ''Pli'''),
      ('when ''payroll_run'' then ''Pay''', 'when ''payroll_run'' then ''Prl'''),
      ('when ''purchase_receipt'' then ''Prc''', 'when ''purchase_receipt'' then ''Prr'''),
      ('when ''cash_payment'' then ''Pay''', 'when ''cash_payment'' then ''Cpy''')
    ) as mappings(old_text, new_text)
  loop
    if position(v_pair.old_text in v_definition) = 0 then
      raise exception 'لم يتم العثور على إعداد البادئة المتوقع: %', v_pair.old_text;
    end if;
    v_definition := replace(v_definition, v_pair.old_text, v_pair.new_text);
  end loop;

  execute v_definition;
end;
$migration$;
