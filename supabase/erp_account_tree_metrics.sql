-- Silsila ERP chart-of-accounts metrics.
-- Apply after supabase/erp_schema.sql.
-- Views use security_invoker so table RLS remains the authority.
-- Balances include posted journal entries only; draft/reversed entries are excluded.

create or replace view public.erp_account_ledger_totals
with (security_invoker = true)
as
select
  a.id as account_id,
  a.company_id,
  coalesce(sum(case when je.status = 'posted' then jl.debit else 0 end), 0)::numeric(18,2) as debit_total,
  coalesce(sum(case when je.status = 'posted' then jl.credit else 0 end), 0)::numeric(18,2) as credit_total,
  coalesce(sum(case when je.status = 'posted' then jl.debit - jl.credit else 0 end), 0)::numeric(18,2) as net_balance,
  count(distinct je.id) filter (where je.status = 'posted')::bigint as movement_count,
  max(je.entry_date) filter (where je.status = 'posted') as last_movement_date
from public.erp_accounts a
left join public.erp_journal_lines jl on jl.account_id = a.id
left join public.erp_journal_entries je
  on je.id = jl.entry_id
 and je.company_id = a.company_id
 and je.status = 'posted'
group by a.id, a.company_id;

create or replace view public.erp_account_tree_metrics
with (security_invoker = true)
as
with recursive account_paths as (
  select
    a.id as ancestor_id,
    a.id as descendant_id,
    a.company_id,
    0 as depth
  from public.erp_accounts a
  union all
  select
    p.ancestor_id,
    child.id as descendant_id,
    p.company_id,
    p.depth + 1
  from account_paths p
  join public.erp_accounts child
    on child.parent_id = p.descendant_id
   and child.company_id = p.company_id
),
descendant_metrics as (
  select
    p.ancestor_id as account_id,
    p.company_id,
    coalesce(sum(t.net_balance), 0)::numeric(18,2) as subtree_net_balance,
    coalesce(sum(t.debit_total), 0)::numeric(18,2) as subtree_debit_total,
    coalesce(sum(t.credit_total), 0)::numeric(18,2) as subtree_credit_total,
    coalesce(sum(t.movement_count), 0)::bigint as subtree_movement_count,
    count(*) filter (where p.depth > 0)::bigint as descendant_account_count,
    count(*) filter (where p.depth > 0 and d.is_postable)::bigint as descendant_postable_count
  from account_paths p
  join public.erp_accounts d
    on d.id = p.descendant_id and d.company_id = p.company_id
  left join public.erp_account_ledger_totals t
    on t.account_id = d.id and t.company_id = d.company_id
  group by p.ancestor_id, p.company_id
),
company_totals as (
  select
    a.company_id,
    coalesce(sum(abs(t.net_balance)) filter (where a.is_postable), 0)::numeric(18,2) as absolute_postable_balance_total
  from public.erp_accounts a
  left join public.erp_account_ledger_totals t
    on t.account_id = a.id and t.company_id = a.company_id
  group by a.company_id
)
select
  a.id as account_id,
  a.company_id,
  a.parent_id,
  a.account_code,
  a.account_name,
  a.account_type,
  a.normal_balance,
  a.is_postable,
  a.is_active,
  coalesce(t.debit_total, 0)::numeric(18,2) as own_debit_total,
  coalesce(t.credit_total, 0)::numeric(18,2) as own_credit_total,
  coalesce(t.net_balance, 0)::numeric(18,2) as own_net_balance,
  coalesce(t.movement_count, 0)::bigint as own_movement_count,
  coalesce(m.subtree_net_balance, 0)::numeric(18,2) as subtree_net_balance,
  coalesce(m.subtree_debit_total, 0)::numeric(18,2) as subtree_debit_total,
  coalesce(m.subtree_credit_total, 0)::numeric(18,2) as subtree_credit_total,
  coalesce(m.subtree_movement_count, 0)::bigint as subtree_movement_count,
  coalesce(m.descendant_account_count, 0)::bigint as descendant_account_count,
  coalesce(m.descendant_postable_count, 0)::bigint as descendant_postable_count,
  coalesce(c.absolute_postable_balance_total, 0)::numeric(18,2) as company_absolute_balance_total,
  case
    when coalesce(c.absolute_postable_balance_total, 0) = 0 then 0::numeric
    else round(abs(coalesce(m.subtree_net_balance, 0)) / c.absolute_postable_balance_total * 100, 2)
  end as subtree_balance_share_percent,
  t.last_movement_date
from public.erp_accounts a
left join public.erp_account_ledger_totals t
  on t.account_id = a.id and t.company_id = a.company_id
left join descendant_metrics m
  on m.account_id = a.id and m.company_id = a.company_id
left join company_totals c on c.company_id = a.company_id;

comment on view public.erp_account_ledger_totals is
  'Posted journal totals by account; respects underlying table RLS through security_invoker.';
comment on view public.erp_account_tree_metrics is
  'Recursive account hierarchy metrics based on posted journal entries; apply company and branch authorization policies before client access.';

-- Explicit grants are required for PostgREST clients; security_invoker keeps base RLS active.
grant select on public.erp_account_ledger_totals, public.erp_account_tree_metrics to authenticated;
