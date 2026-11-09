-- Let the dedicated category-tree trigger assign Cat + main/sub/secondary segments.
do $$
declare
  v_definition text;
  v_old text := '  if nullif(to_jsonb(new)->>v_column, '''') is not null then return new; end if;';
  v_new text := '  if tg_table_name = ''erp_item_categories'' then return new; end if;' || E'\n' ||
                '  if nullif(to_jsonb(new)->>v_column, '''') is not null then return new; end if;';
begin
  select pg_get_functiondef('public.erp_assign_central_code()'::regprocedure)
    into v_definition;
  if position(v_old in v_definition) = 0 then
    raise exception 'Could not locate central-code early-return anchor';
  end if;
  execute replace(v_definition, v_old, v_new);
end;
$$;
