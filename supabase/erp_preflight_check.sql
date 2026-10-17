-- Silsila ERP installation preflight. Read-only diagnostics for Supabase SQL Editor.
-- Run after the ERP migrations. No application records are changed.

select
  x.object_name,
  x.object_type,
  case
    when x.object_type in ('table','view') and to_regclass('public.' || x.object_name) is not null then 'موجود'
    when x.object_type = 'function' and exists (
      select 1 from pg_proc p join pg_namespace n on n.oid = p.pronamespace
      where n.nspname = 'public' and p.proname = x.object_name
    ) then 'موجود'
    else 'غير موجود'
  end as installation_status
from (values
  ('erp_companies','table'),
  ('erp_company_members','table'),
  ('erp_accounts','table'),
  ('erp_journal_entries','table'),
  ('erp_journal_lines','table'),
  ('erp_fiscal_periods','table'),
  ('erp_employees','table'),
  ('erp_attendance_records','table'),
  ('erp_leave_requests','table'),
  ('erp_payroll_runs','table'),
  ('erp_payroll_lines','table'),
  ('erp_warehouses','table'),
  ('erp_items','table'),
  ('erp_inventory_movements','table'),
  ('erp_purchase_documents','table'),
  ('erp_purchase_lines','table'),
  ('erp_sales_documents','table'),
  ('erp_sales_lines','table'),
  ('erp_stock_balances','view'),
  ('erp_cash_vouchers','table'),
  ('erp_employee_directory','view'),
  ('erp_account_ledger_totals','view'),
  ('erp_account_tree_metrics','view'),
  ('erp_general_ledger','view'),
  ('erp_save_journal_draft','function'),
  ('erp_post_journal_entry','function'),
  ('erp_get_trial_balance','function'),
  ('erp_reverse_journal_entry','function'),
  ('erp_run_movement_audit','function'),
  ('erp_add_operational_document_line','function'),
  ('erp_post_purchase_document','function'),
  ('erp_post_sales_document','function'),
  ('erp_post_cash_voucher','function'),
  ('erp_recalculate_payroll_run','function'),
  ('erp_approve_payroll_run','function'),
  ('erp_post_payroll_run','function'),
  ('erp_decide_leave_request','function'),
  ('erp_record_inventory_movement','function'),
  ('erp_transfer_inventory_between_warehouses','function')
) as x(object_name, object_type)
order by x.object_type, x.object_name;

select
  c.relname as table_name,
  c.relrowsecurity as rls_enabled,
  c.relforcerowsecurity as rls_forced,
  count(p.polname)::integer as policy_count
from pg_class c
join pg_namespace n on n.oid = c.relnamespace
left join pg_policy p on p.polrelid = c.oid
where n.nspname = 'public'
  and c.relkind in ('r','p')
  and c.relname like 'erp_%'
group by c.relname, c.relrowsecurity, c.relforcerowsecurity
order by c.relname;

select
  p.proname as function_name,
  pg_get_function_identity_arguments(p.oid) as arguments,
  has_function_privilege('authenticated', p.oid, 'EXECUTE') as authenticated_can_execute
from pg_proc p
join pg_namespace n on n.oid = p.pronamespace
where n.nspname = 'public'
  and p.proname in (
    'erp_save_journal_draft',
    'erp_post_journal_entry',
    'erp_get_trial_balance',
    'erp_reverse_journal_entry',
    'erp_run_movement_audit',
    'erp_add_operational_document_line',
    'erp_post_purchase_document',
    'erp_post_sales_document',
    'erp_post_cash_voucher',
    'erp_recalculate_payroll_run',
    'erp_approve_payroll_run',
    'erp_post_payroll_run',
    'erp_decide_leave_request',
    'erp_record_inventory_movement',
    'erp_transfer_inventory_between_warehouses'
  )
order by p.proname;
