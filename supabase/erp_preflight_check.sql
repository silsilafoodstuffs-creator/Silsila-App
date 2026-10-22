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
  ('erp_cost_centers','table'),
  ('erp_company_settings','table'),
  ('erp_delegate_item_assignments','table'),
  ('erp_managed_apps','table'),
  ('erp_app_theme_settings','table'),
  ('erp_app_assets','table'),
  ('erp_app_role_permissions','table'),
  ('erp_company_members','table'),
  ('erp_currencies','table'),
  ('erp_geo_areas','table'),
  ('erp_sales_representatives','table'),
  ('erp_customer_monthly_goals','table'),
  ('erp_commission_plans','table'),
  ('erp_commission_tiers','table'),
  ('erp_commission_runs','table'),
  ('erp_einvoice_settings','table'),
  ('erp_einvoice_operations','table'),
  ('erp_hr_shifts','table'),
  ('erp_hr_shift_assignments','table'),
  ('erp_hr_fingerprint_devices','table'),
  ('erp_hr_attendance_events','table'),
  ('erp_accounts','table'),
  ('erp_parties','table'),
  ('erp_branches','table'),
  ('erp_cashboxes','table'),
  ('erp_item_categories','table'),
  ('erp_item_units','table'),
  ('erp_party_contacts','table'),
  ('erp_price_lists','table'),
  ('erp_price_list_lines','table'),
  ('erp_party_price_lists','table'),
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
  ('erp_operational_account_mappings','table'),
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
  ('erp_post_operational_document_accounting','function'),
  ('erp_validate_operational_account_mappings','function'),
  ('erp_post_cash_voucher','function'),
  ('erp_recalculate_payroll_run','function'),
  ('erp_approve_payroll_run','function'),
  ('erp_post_payroll_run','function'),
  ('erp_decide_leave_request','function'),
  ('erp_guard_fiscal_period','function'),
  ('erp_validate_master_data_links','function'),
  ('erp_resolve_item_price','function'),
  ('erp_create_price_list','function'),
  ('erp_validate_cash_voucher_links','function'),
  ('erp_require_cash_voucher_draft','function'),
  ('erp_guard_cash_voucher_update','function'),
  ('erp_record_inventory_movement','function'),
  ('erp_transfer_inventory_between_warehouses','function'),
  ('erp_validate_delegate_item_assignment','function'),
  ('erp_validate_hr_company_links','function'),
  ('erp_validate_hr_attendance_links','function'),
  ('erp_validate_sales_target_links','function')
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
category by c.relname, c.relrowsecurity, c.relforcerowsecurity
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
    'erp_post_operational_document_accounting',
    'erp_post_cash_voucher',
    'erp_recalculate_payroll_run',
    'erp_approve_payroll_run',
    'erp_post_payroll_run',
    'erp_decide_leave_request',
    'erp_record_inventory_movement',
    'erp_transfer_inventory_between_warehouses',
    'erp_validate_cash_voucher_links',
    'erp_require_cash_voucher_draft',
    'erp_guard_cash_voucher_update',
    'erp_validate_master_data_links',
    'erp_resolve_item_price',
    'erp_create_price_list',
    'erp_validate_hr_company_links',
    'erp_validate_hr_attendance_links',
    'erp_validate_sales_target_links'
  )
order by p.proname;
