-- Silsila ERP general ledger and trial balance.
-- Apply after erp_schema.sql and the journal workflow migration.
-- Read access continues to be governed by RLS on underlying tables.

create or replace view public.erp_general_ledger
with (security_invoker = true)
as
select
  je.company_id,
  je.id as entry_id,
  je.entry_number,
  je.entry_date,
  je.description as entry_description,
  je.source_type,
  je.status,
  jl.id as line_id,
  jl.account_id,
  a.account_code,
  a.account_name,
  jl.description as line_description,
  jl.debit,
  jl.credit,
  (jl.debit - jl.credit)::numeric(18,2) as net_change,
  jl.party_id,
  jl.branch_id
from public.erp_journal_entries je
join public.erp_journal_lines jl on jl.entry_id = je.id
join public.erp_accounts a on a.id = jl.account_id and a.company_id = je.company_id
where je.status = 'posted';

create or replace function public.erp_get_trial_balance(
  p_company_id uuid,
  p_start_date date default null,
  p_end_date date default null
)
returns table (
  account_id uuid,
  account_code text,
  account_name text,
  account_type text,
  normal_balance text,
  debit_total numeric,
  credit_total numeric,
  net_balance numeric
)
language plpgsql
security invoker
set search_path = public
as $$
begin
  if p_company_id is null then
    raise exception 'معرّف الشركة مطلوب';
  end if;
  if p_start_date is not null and p_end_date is not null and p_start_date > p_end_date then
    raise exception 'تاريخ البداية يجب ألا يتجاوز تاريخ النهاية';
  end if;

  return query
  select
    a.id,
    a.account_code,
    a.account_name,
    a.account_type,
    a.normal_balance,
    coalesce(sum(case when je.id is not null then jl.debit else 0 end), 0)::numeric as debit_total,
    coalesce(sum(case when je.id is not null then jl.credit else 0 end), 0)::numeric as credit_total,
    coalesce(sum(case when je.id is not null then jl.debit - jl.credit else 0 end), 0)::numeric as net_balance
  from public.erp_accounts a
  left join public.erp_journal_lines jl on jl.account_id = a.id
  left join public.erp_journal_entries je
    on je.id = jl.entry_id
   and je.company_id = a.company_id
   and je.status = 'posted'
   and (p_start_date is null or je.entry_date >= p_start_date)
   and (p_end_date is null or je.entry_date <= p_end_date)
  where a.company_id = p_company_id
  group by a.id, a.account_code, a.account_name, a.account_type, a.normal_balance
  order by a.account_code;
end;
$$;

revoke all on function public.erp_get_trial_balance(uuid,date,date) from public, anon;
grant execute on function public.erp_get_trial_balance(uuid,date,date) to authenticated;

comment on view public.erp_general_ledger is
  'Detailed posted journal lines only; security_invoker preserves base-table RLS.';
comment on function public.erp_get_trial_balance(uuid,date,date) is
  'Trial balance by company and optional inclusive date range, using posted entries only; respects RLS.';

-- Explicit read grant for authenticated clients; the view remains subject to base-table RLS.
grant select on public.erp_general_ledger to authenticated;
