-- Cover the foreign-key lookup paths introduced by HR, commissions, and delegate assignments.
create index if not exists erp_attendance_recorded_by_idx on public.erp_attendance_records(recorded_by);
create index if not exists erp_commission_runs_company_idx on public.erp_commission_runs(company_id);
create index if not exists erp_commission_runs_plan_idx on public.erp_commission_runs(plan_id);
create index if not exists erp_commission_runs_representative_idx on public.erp_commission_runs(representative_id);
create index if not exists erp_customer_goals_customer_idx on public.erp_customer_monthly_goals(customer_id);
create index if not exists erp_delegate_assignment_assigned_by_idx on public.erp_delegate_item_assignments(assigned_by);
create index if not exists erp_delegate_assignment_employee_fk_idx on public.erp_delegate_item_assignments(employee_id);
create index if not exists erp_delegate_assignment_item_fk_idx on public.erp_delegate_item_assignments(item_id);
create index if not exists erp_employees_branch_idx on public.erp_employees(branch_id);
create index if not exists erp_leave_employee_idx on public.erp_leave_requests(employee_id);
create index if not exists erp_leave_approved_by_idx on public.erp_leave_requests(approved_by);
create index if not exists erp_parties_geo_area_idx on public.erp_parties(geo_area_id);
create index if not exists erp_payroll_lines_employee_fk_idx on public.erp_payroll_lines(employee_id);
create index if not exists erp_payroll_runs_approved_by_idx on public.erp_payroll_runs(approved_by);
create index if not exists erp_payroll_runs_created_by_idx on public.erp_payroll_runs(created_by);
create index if not exists erp_payroll_runs_deductions_account_idx on public.erp_payroll_runs(deductions_account_id);
create index if not exists erp_payroll_runs_expense_account_idx on public.erp_payroll_runs(expense_account_id);
create index if not exists erp_payroll_runs_journal_entry_idx on public.erp_payroll_runs(journal_entry_id);
create index if not exists erp_payroll_runs_payable_account_idx on public.erp_payroll_runs(payable_account_id);
create index if not exists erp_sales_representatives_home_area_idx on public.erp_sales_representatives(home_area_id);

drop policy if exists erp_delegate_item_assignments_insert_manager on public.erp_delegate_item_assignments;
create policy erp_delegate_item_assignments_insert_manager
on public.erp_delegate_item_assignments for insert to authenticated
with check (
  (assigned_by is null or assigned_by = (select auth.uid()))
  and public.erp_user_has_company_role(company_id, array['owner','admin','manager']::text[])
);
drop policy if exists erp_delegate_item_assignments_update_manager on public.erp_delegate_item_assignments;
create policy erp_delegate_item_assignments_update_manager
on public.erp_delegate_item_assignments for update to authenticated
using (public.erp_user_has_company_role(company_id, array['owner','admin','manager']::text[]))
with check (
  (assigned_by is null or assigned_by = (select auth.uid()))
  and public.erp_user_has_company_role(company_id, array['owner','admin','manager']::text[])
);
