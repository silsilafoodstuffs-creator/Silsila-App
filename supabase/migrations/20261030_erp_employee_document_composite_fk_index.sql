-- Cover the employee/company composite foreign key in its declared column order.
create index if not exists erp_employee_documents_employee_company_fk_idx
  on public.erp_employee_documents (employee_id, company_id);
