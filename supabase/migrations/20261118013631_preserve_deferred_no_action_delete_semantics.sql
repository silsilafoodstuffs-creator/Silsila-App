create or replace function private.erp_prevent_delete_when_referenced()
returns trigger
language plpgsql
security definer
set search_path = pg_catalog
as $function$
declare
  fk record;
  has_references boolean;
begin
  for fk in
    select
      con.conname,
      child_ns.nspname as child_schema,
      child.relname as child_table,
      string_agg(
        format('c.%I IS NOT DISTINCT FROM ($1).%I', child_att.attname, parent_att.attname),
        ' AND ' order by key_cols.ordinality
      ) as match_predicate
    from pg_catalog.pg_constraint con
    join pg_catalog.pg_class child on child.oid = con.conrelid
    join pg_catalog.pg_namespace child_ns on child_ns.oid = child.relnamespace
    cross join lateral unnest(con.conkey, con.confkey) with ordinality
      as key_cols(child_attnum, parent_attnum, ordinality)
    join pg_catalog.pg_attribute child_att
      on child_att.attrelid = con.conrelid and child_att.attnum = key_cols.child_attnum
    join pg_catalog.pg_attribute parent_att
      on parent_att.attrelid = con.confrelid and parent_att.attnum = key_cols.parent_attnum
    where con.contype = 'f'
      and con.confrelid = tg_relid
      and con.confdeltype = 'r'
      and con.convalidated
    group by con.oid, con.conname, child_ns.nspname, child.relname
  loop
    execute format(
      'select exists (select 1 from %I.%I c where %s)',
      fk.child_schema, fk.child_table, fk.match_predicate
    ) into has_references using old;

    if has_references then
      raise exception using
        errcode = '23503',
        message = format('تعذر حذف السجل من %I.%I لوجود بيانات مرتبطة في %I.%I.',
                         tg_table_schema, tg_table_name, fk.child_schema, fk.child_table),
        detail = format('Foreign key constraint: %s', fk.conname),
        hint = 'احذف أو عالج السجلات التابعة من شاشاتها المخصصة أولاً، ثم أعد المحاولة.';
    end if;
  end loop;
  return old;
end;
$function$;

do $install$
declare parent record;
begin
  for parent in
    select distinct parent_ns.nspname as schema_name, parent_table.relname as table_name
    from pg_catalog.pg_constraint con
    join pg_catalog.pg_class parent_table on parent_table.oid = con.confrelid
    join pg_catalog.pg_namespace parent_ns on parent_ns.oid = parent_table.relnamespace
    where con.contype = 'f'
      and con.confdeltype = 'r'
      and con.convalidated
      and parent_ns.nspname in ('public', 'auth')
      and parent_table.relkind in ('r', 'p')
  loop
    execute format('drop trigger if exists erp_prevent_referenced_delete on %I.%I',
                   parent.schema_name, parent.table_name);
    execute format(
      'create trigger erp_prevent_referenced_delete before delete on %I.%I for each row execute function private.erp_prevent_delete_when_referenced()',
      parent.schema_name, parent.table_name
    );
  end loop;
end;
$install$;

do $cleanup$
declare old_trigger record;
begin
  for old_trigger in
    select n.nspname as schema_name, c.relname as table_name
    from pg_catalog.pg_trigger t
    join pg_catalog.pg_class c on c.oid=t.tgrelid
    join pg_catalog.pg_namespace n on n.oid=c.relnamespace
    where t.tgname='erp_prevent_referenced_delete'
      and not t.tgisinternal
      and n.nspname in ('public','auth')
      and not exists (
        select 1 from pg_catalog.pg_constraint con
        where con.contype='f' and con.confrelid=c.oid and con.confdeltype='r' and con.convalidated
      )
  loop
    execute format('drop trigger if exists erp_prevent_referenced_delete on %I.%I',
                   old_trigger.schema_name, old_trigger.table_name);
  end loop;
end;
$cleanup$;
