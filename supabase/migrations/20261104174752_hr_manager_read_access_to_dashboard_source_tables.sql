
drop policy if exists erp_employees_select_hr on public.erp_employees;
create policy erp_employees_select_hr on public.erp_employees for select using (
  public.erp_user_has_company_role(company_id, array['owner','admin','manager','accountant'])
  or exists (select 1 from public.erp_company_member_profiles p where p.company_id=erp_employees.company_id and p.user_id=auth.uid() and trim(coalesce(p.job_title,''))='مدير موارد بشرية')
);
drop policy if exists erp_attendance_select_hr on public.erp_attendance_records;
create policy erp_attendance_select_hr on public.erp_attendance_records for select using (
  public.erp_user_has_company_role(company_id, array['owner','admin','manager','accountant','operator'])
  or exists (select 1 from public.erp_company_member_profiles p where p.company_id=erp_attendance_records.company_id and p.user_id=auth.uid() and trim(coalesce(p.job_title,''))='مدير موارد بشرية')
);
drop policy if exists erp_leave_select_hr on public.erp_leave_requests;
create policy erp_leave_select_hr on public.erp_leave_requests for select using (
  public.erp_user_has_company_role(company_id, array['owner','admin','manager','accountant','operator'])
  or exists (select 1 from public.erp_company_member_profiles p where p.company_id=erp_leave_requests.company_id and p.user_id=auth.uid() and trim(coalesce(p.job_title,''))='مدير موارد بشرية')
);
drop policy if exists erp_payroll_runs_select_finance on public.erp_payroll_runs;
create policy erp_payroll_runs_select_finance on public.erp_payroll_runs for select using (
  public.erp_user_has_company_role(company_id, array['owner','admin','manager','accountant'])
  or exists (select 1 from public.erp_company_member_profiles p where p.company_id=erp_payroll_runs.company_id and p.user_id=auth.uid() and trim(coalesce(p.job_title,''))='مدير موارد بشرية')
);
drop policy if exists erp_employee_documents_select_member on public.erp_employee_documents;
create policy erp_employee_documents_select_member on public.erp_employee_documents for select using (
  public.erp_user_has_company_role(company_id, array['owner','admin','manager'])
  or exists (select 1 from public.erp_company_member_profiles p where p.company_id=erp_employee_documents.company_id and p.user_id=auth.uid() and trim(coalesce(p.job_title,''))='مدير موارد بشرية')
);
