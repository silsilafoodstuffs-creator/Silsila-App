create table if not exists public.erp_hr_salary_elements (
  id uuid primary key default gen_random_uuid(),
  company_id uuid not null references public.erp_companies(id) on delete cascade,
  element_code text not null,
  name_ar text not null,
  name_en text not null default '',
  element_type text not null check (element_type in ('earning','deduction')),
  value_mode text not null check (value_mode in ('fixed','variable')),
  nature text not null check (nature in ('value','time','days')),
  default_value numeric(6,3) not null default 0 check (default_value >= 0 and default_value <= 999.999),
  show_on_payslip boolean not null default true,
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint erp_hr_salary_elements_company_code_uq unique(company_id, element_code),
  constraint erp_hr_salary_elements_code_format check (element_code ~ '^[A-Za-z0-9]+$')
);

alter table public.erp_payroll_lines
  add column if not exists element_values jsonb not null default '{}'::jsonb;

create index if not exists erp_hr_salary_elements_company_active_idx
  on public.erp_hr_salary_elements(company_id, is_active, element_type);

alter table public.erp_hr_salary_elements enable row level security;

drop policy if exists erp_hr_salary_elements_select_company on public.erp_hr_salary_elements;
create policy erp_hr_salary_elements_select_company
  on public.erp_hr_salary_elements for select to authenticated
  using (erp_user_has_company_role(company_id, array['owner','admin','manager','accountant']));

drop policy if exists erp_hr_salary_elements_insert_manager on public.erp_hr_salary_elements;
create policy erp_hr_salary_elements_insert_manager
  on public.erp_hr_salary_elements for insert to authenticated
  with check (erp_user_has_company_role(company_id, array['owner','admin','manager']));

drop policy if exists erp_hr_salary_elements_update_manager on public.erp_hr_salary_elements;
create policy erp_hr_salary_elements_update_manager
  on public.erp_hr_salary_elements for update to authenticated
  using (erp_user_has_company_role(company_id, array['owner','admin','manager']))
  with check (erp_user_has_company_role(company_id, array['owner','admin','manager']));

drop policy if exists erp_hr_salary_elements_delete_admin on public.erp_hr_salary_elements;
create policy erp_hr_salary_elements_delete_admin
  on public.erp_hr_salary_elements for delete to authenticated
  using (erp_user_has_company_role(company_id, array['owner','admin']));

grant select, insert, update, delete on public.erp_hr_salary_elements to authenticated;
