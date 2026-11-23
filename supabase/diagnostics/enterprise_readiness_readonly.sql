-- Silsila enterprise-readiness diagnostics
-- READ ONLY: run in Supabase SQL Editor with an appropriately privileged operator.
-- No SET ROLE, DDL, DML, GRANT/REVOKE, ANALYZE, or statistics reset is performed.

-- 1) SECURITY DEFINER inventory and exposure flags.
select
  p.oid::regprocedure::text as function_signature,
  has_function_privilege('anon', p.oid, 'EXECUTE') as anon_can_execute,
  has_function_privilege('authenticated', p.oid, 'EXECUTE') as authenticated_can_execute,
  coalesce(array_to_string(p.proconfig, '; '), '') ilike '%search_path%' as explicit_search_path,
  pg_get_function_result(p.oid) as result_type
from pg_proc p
join pg_namespace n on n.oid = p.pronamespace
where n.nspname = 'public'
  and p.prosecdef
order by p.proname, p.oid::regprocedure::text;

-- 2) RLS-enabled public tables with no policy. Review archive/secret tables before
-- adding any policy; an empty policy set can be the intended private posture.
select
  c.relname as table_name,
  pg_size_pretty(pg_total_relation_size(c.oid)) as total_size,
  coalesce(st.n_live_tup, 0) as estimated_rows
from pg_class c
join pg_namespace n on n.oid = c.relnamespace
left join pg_stat_user_tables st on st.relid = c.oid
where n.nspname = 'public'
  and c.relkind = 'r'
  and c.relrowsecurity
  and not exists (
    select 1 from pg_policies pol
    where pol.schemaname = n.nspname
      and pol.tablename = c.relname
  )
order by pg_total_relation_size(c.oid) desc;

-- 3) Foreign keys without a covering left-prefix index. This is a candidate list,
-- not an instruction to create every index; prioritize by real plans and workload.
with fk as (
  select
    con.oid,
    con.conname,
    con.conrelid,
    con.conkey,
    st.n_live_tup as estimated_rows
  from pg_constraint con
  join pg_class c on c.oid = con.conrelid
  join pg_namespace n on n.oid = c.relnamespace
  left join pg_stat_user_tables st on st.relid = con.conrelid
  where con.contype = 'f'
    and n.nspname = 'public'
)
select
  conname,
  conrelid::regclass::text as table_name,
  pg_size_pretty(pg_total_relation_size(conrelid)) as total_size,
  coalesce(estimated_rows, 0) as estimated_rows,
  pg_get_constraintdef(oid) as foreign_key
from fk
where not exists (
  select 1
  from pg_index ix
  where ix.indrelid = fk.conrelid
    and ix.indisvalid
    and ix.indisready
    and (
      select array_agg(k order by k)
      from unnest(ix.indkey::smallint[]) k
      where k > 0
    ) @> (
      select array_agg(k order by k)
      from unnest(fk.conkey) k
    )
)
order by coalesce(estimated_rows, 0) desc,
         pg_total_relation_size(conrelid) desc;

-- 4) Slow/high-cost normalized query fingerprints. Query text is intentionally
-- omitted here; use a privileged review process before exporting SQL text.
select
  queryid,
  calls,
  round(mean_exec_time::numeric, 2) as mean_ms,
  round(max_exec_time::numeric, 2) as max_ms,
  round(total_exec_time::numeric, 2) as total_ms,
  rows,
  shared_blks_hit,
  shared_blks_read,
  temp_blks_read,
  temp_blks_written
from extensions.pg_stat_statements
where calls > 5
order by total_exec_time desc
limit 50;

-- 5) Table scan and write counters. Compare over a documented interval; these
-- counters are cumulative since the last statistics reset.
select
  relname as table_name,
  n_live_tup as estimated_rows,
  seq_scan,
  seq_tup_read,
  idx_scan,
  n_tup_ins,
  n_tup_upd,
  n_tup_del,
  pg_size_pretty(pg_total_relation_size(relid)) as total_size
from pg_stat_user_tables
where schemaname = 'public'
order by seq_tup_read desc
limit 50;
