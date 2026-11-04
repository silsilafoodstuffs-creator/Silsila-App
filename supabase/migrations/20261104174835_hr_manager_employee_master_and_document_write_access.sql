
drop policy if exists erp_employees_update_hr on public.erp_employees;
create policy erp_employees_update_hr on public.erp_employees for update using (
  public.erp_user_has_company_role(company_id, array['owner','admin','manager'])
  or exists (select 1 from public.erp_company_member_profiles p where p.company_id=erp_employees.company_id and p.user_id=auth.uid() and trim(coalesce(p.job_title,''))='مدير موارد بشرية')
) with check (
  public.erp_user_has_company_role(company_id, array['owner','admin','manager'])
  or exists (select 1 from public.erp_company_member_profiles p where p.company_id=erp_employees.company_id and p.user_id=auth.uid() and trim(coalesce(p.job_title,''))='مدير موارد بشرية')
);
drop policy if exists erp_employee_documents_insert_hr on public.erp_employee_documents;
create policy erp_employee_documents_insert_hr on public.erp_employee_documents for insert with check (
  public.erp_user_has_company_role(company_id, array['owner','admin','manager'])
  or exists (select 1 from public.erp_company_member_profiles p where p.company_id=erp_employee_documents.company_id and p.user_id=auth.uid() and trim(coalesce(p.job_title,''))='مدير موارد بشرية')
);
drop policy if exists erp_employee_documents_update_hr on public.erp_employee_documents;
create policy erp_employee_documents_update_hr on public.erp_employee_documents for update using (
  public.erp_user_has_company_role(company_id, array['owner','admin','manager'])
  or exists (select 1 from public.erp_company_member_profiles p where p.company_id=erp_employee_documents.company_id and p.user_id=auth.uid() and trim(coalesce(p.job_title,''))='مدير موارد بشرية')
) with check (
  public.erp_user_has_company_role(company_id, array['owner','admin','manager'])
  or exists (select 1 from public.erp_company_member_profiles p where p.company_id=erp_employee_documents.company_id and p.user_id=auth.uid() and trim(coalesce(p.job_title,''))='مدير موارد بشرية')
);
drop policy if exists erp_employee_documents_delete_admin on public.erp_employee_documents;
create policy erp_employee_documents_delete_admin on public.erp_employee_documents for delete using (
  public.erp_user_has_company_role(company_id, array['owner','admin','manager'])
  or exists (select 1 from public.erp_company_member_profiles p where p.company_id=erp_employee_documents.company_id and p.user_id=auth.uid() and trim(coalesce(p.job_title,''))='مدير موارد بشرية')
);
