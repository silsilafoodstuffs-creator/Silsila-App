begin;

revoke all privileges on table
  public.erp_attendance_records,
  public.erp_business_workspace_employee_leaves,
  public.erp_employee_documents,
  public.erp_employee_monthly_targets,
  public.erp_leave_requests,
  public.erp_payroll_lines,
  public.erp_payroll_runs
from anon;

alter policy erp_attendance_select_hr
  on public.erp_attendance_records to authenticated;

alter policy erp_employee_documents_select_member
  on public.erp_employee_documents to authenticated;
alter policy erp_employee_documents_insert_hr
  on public.erp_employee_documents to authenticated;
alter policy erp_employee_documents_update_hr
  on public.erp_employee_documents to authenticated;
alter policy erp_employee_documents_delete_admin
  on public.erp_employee_documents to authenticated;

alter policy erp_leave_select_hr
  on public.erp_leave_requests to authenticated;

alter policy erp_payroll_runs_select_finance
  on public.erp_payroll_runs to authenticated;

commit;
