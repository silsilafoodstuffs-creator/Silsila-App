-- Silsila ERP movement audit table.
-- Review the deployed tenant model and add restrictive RLS policies before use.
-- RLS is enabled with no permissive policy, so clients remain denied by default.
-- For high-integrity audit, critical events should be written by trusted server workflows.

create table if not exists public.erp_movement_audit (
  id uuid primary key default gen_random_uuid(),
  company_id uuid not null references public.erp_companies(id) on delete restrict,
  area_key text not null,
  action_key text not null,
  entity_type text not null,
  entity_id uuid,
  reference_code text,
  description text,
  details jsonb not null default '{}'::jsonb,
  actor_user_id uuid references auth.users(id) on delete set null,
  created_at timestamptz not null default now()
);

create index if not exists erp_movement_audit_company_created_idx
  on public.erp_movement_audit(company_id, created_at desc);

create index if not exists erp_movement_audit_company_area_created_idx
  on public.erp_movement_audit(company_id, area_key, created_at desc);

alter table public.erp_movement_audit enable row level security;

comment on table public.erp_movement_audit is
  'Company-scoped audit trail. Add reviewed company-membership policies before production use.';


-- Read-only movement consistency report for the ERP admin screen.
-- Apply after erp_schema.sql and erp_operations_schema.sql.
-- Execute only through a trusted backend; never expose service_role in Flutter.
create or replace function public.erp_audit_movements(
  p_company_id uuid,
  p_start_date date default null,
  p_end_date date default null,
  p_area text default 'كل الحركات'
)
returns table (
  area text,
  document_id uuid,
  document_number text,
  document_date date,
  amount numeric(14,2),
  issue_code text,
  issue_message text,
  severity text
)
language sql
stable
security invoker
set search_path = public
as $$
  select 'المبيعات'::text, d.id, d.document_number, d.document_date,
    d.grand_total::numeric(14,2), 'POSTED_SALES_WITHOUT_LINES'::text,
    'مستند مبيعات مرحّل دون سطور أصناف'::text, 'error'::text
  from public.erp_sales_documents d
  where d.company_id = p_company_id and d.status = 'posted'
    and (p_start_date is null or d.document_date >= p_start_date)
    and (p_end_date is null or d.document_date <= p_end_date)
    and not exists (select 1 from public.erp_sales_lines l where l.document_id = d.id)
    and (p_area = 'كل الحركات' or p_area = 'المبيعات')

  union all

  select 'الموردون'::text, d.id, d.document_number, d.document_date,
    d.grand_total::numeric(14,2), 'POSTED_PURCHASE_WITHOUT_LINES'::text,
    'مستند مشتريات مرحّل دون سطور أصناف'::text, 'error'::text
  from public.erp_purchase_documents d
  where d.company_id = p_company_id and d.status = 'posted'
    and (p_start_date is null or d.document_date >= p_start_date)
    and (p_end_date is null or d.document_date <= p_end_date)
    and not exists (select 1 from public.erp_purchase_lines l where l.document_id = d.id)
    and (p_area = 'كل الحركات' or p_area = 'الموردون')

  union all

  select 'المبيعات'::text, d.id, d.document_number, d.document_date,
    d.grand_total::numeric(14,2), 'POSTED_SALES_WITHOUT_JOURNAL'::text,
    'مستند المبيعات مرحّل ولا يوجد قيد يومية مرتبط به عبر source_id'::text, 'warning'::text
  from public.erp_sales_documents d
  where d.company_id = p_company_id and d.status = 'posted'
    and (p_start_date is null or d.document_date >= p_start_date)
    and (p_end_date is null or d.document_date <= p_end_date)
    and not exists (select 1 from public.erp_journal_entries j
      where j.company_id = d.company_id and j.source_id = d.id and j.status = 'posted')
    and (p_area = 'كل الحركات' or p_area in ('المبيعات','القيود المحاسبية'))

  union all

  select 'الموردون'::text, d.id, d.document_number, d.document_date,
    d.grand_total::numeric(14,2), 'POSTED_PURCHASE_WITHOUT_JOURNAL'::text,
    'مستند المشتريات مرحّل ولا يوجد قيد يومية مرتبط به عبر source_id'::text, 'warning'::text
  from public.erp_purchase_documents d
  where d.company_id = p_company_id and d.status = 'posted'
    and (p_start_date is null or d.document_date >= p_start_date)
    and (p_end_date is null or d.document_date <= p_end_date)
    and not exists (select 1 from public.erp_journal_entries j
      where j.company_id = d.company_id and j.source_id = d.id and j.status = 'posted')
    and (p_area = 'كل الحركات' or p_area in ('الموردون','القيود المحاسبية'))

  union all

  select 'القيود المحاسبية'::text, j.id, j.entry_number::text, j.entry_date,
    0::numeric(14,2), 'POSTED_JOURNAL_WITHOUT_LINES'::text,
    'قيد يومية مرحّل دون أي سطور مدين أو دائن'::text, 'error'::text
  from public.erp_journal_entries j
  where j.company_id = p_company_id and j.status = 'posted'
    and (p_start_date is null or j.entry_date >= p_start_date)
    and (p_end_date is null or j.entry_date <= p_end_date)
    and not exists (select 1 from public.erp_journal_lines l where l.entry_id = j.id)
    and (p_area = 'كل الحركات' or p_area = 'القيود المحاسبية')

  union all

  select 'القيود المحاسبية'::text, j.id, j.entry_number::text, j.entry_date,
    coalesce(sum(l.debit),0)::numeric(14,2), 'UNBALANCED_POSTED_JOURNAL'::text,
    ('القيد غير متوازن؛ المدين ' || to_char(coalesce(sum(l.debit),0),'FM999999999999990.00')
      || ' والدائن ' || to_char(coalesce(sum(l.credit),0),'FM999999999999990.00'))::text,
    'error'::text
  from public.erp_journal_entries j
  left join public.erp_journal_lines l on l.entry_id = j.id
  where j.company_id = p_company_id and j.status = 'posted'
    and (p_start_date is null or j.entry_date >= p_start_date)
    and (p_end_date is null or j.entry_date <= p_end_date)
    and (p_area = 'كل الحركات' or p_area = 'القيود المحاسبية')
  group by j.id, j.entry_number, j.entry_date
  having abs(coalesce(sum(l.debit),0)-coalesce(sum(l.credit),0)) > 0.01

  union all

  select 'المخازن'::text, m.id,
    coalesce(m.reference_type,'حركة مخزون') || ':' || coalesce(m.reference_id::text,m.id::text),
    m.movement_date::date, (m.quantity_in*m.unit_cost)::numeric(14,2),
    'INVENTORY_ITEM_COMPANY_MISMATCH'::text,
    'الشركة المسجلة للحركة لا تطابق الشركة المالكة للصنف'::text, 'error'::text
  from public.erp_inventory_movements m
  join public.erp_items i on i.id = m.item_id
  where m.company_id = p_company_id and i.company_id <> m.company_id
    and (p_start_date is null or m.movement_date::date >= p_start_date)
    and (p_end_date is null or m.movement_date::date <= p_end_date)
    and (p_area = 'كل الحركات' or p_area = 'المخازن')
  order by document_date, area, document_number;
$$;

revoke all on function public.erp_audit_movements(uuid, date, date, text) from public;
revoke all on function public.erp_audit_movements(uuid, date, date, text) from anon, authenticated;
grant execute on function public.erp_audit_movements(uuid, date, date, text) to service_role;

comment on function public.erp_audit_movements(uuid, date, date, text) is
'Read-only audit report for posted sales, purchases, inventory ownership and journal integrity. Call from a trusted backend.';
