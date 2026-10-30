-- Add leading-column indexes for foreign keys flagged by Supabase performance advisors.
-- These indexes are intentionally narrow and do not remove or replace existing indexes.
create index if not exists erp_employee_documents_employee_id_fk_idx
  on public.erp_employee_documents (employee_id);

create index if not exists erp_hr_departments_work_location_id_fk_idx
  on public.erp_hr_departments (work_location_id);

create index if not exists erp_sales_representatives_employee_id_fk_idx
  on public.erp_sales_representatives (employee_id);

create index if not exists erp_users_cashbox_id_fk_idx
  on public.erp_users (cashbox_id);

-- The employee/company composite foreign key uses this exact leading-column order.
create index if not exists erp_employee_documents_employee_company_fk_idx
  on public.erp_employee_documents (employee_id, company_id);
