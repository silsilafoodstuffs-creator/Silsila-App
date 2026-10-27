-- Employee master contract and emergency contact fields.
-- Safe to apply after the HR master-data migration.
alter table public.erp_employees
  add column if not exists administration_id uuid references public.erp_hr_departments(id) on delete set null,
  add column if not exists contract_type text not null default 'بدون عقد',
  add column if not exists contract_start_date date,
  add column if not exists contract_end_date date,
  add column if not exists relative_mobile text,
  add column if not exists relative_relation text;

alter table public.erp_employees drop constraint if exists erp_employees_contract_type_check;
alter table public.erp_employees add constraint erp_employees_contract_type_check
  check (contract_type in ('بعقد','بدون عقد','شركة عمالة','مؤقت','يومية'));

alter table public.erp_employees drop constraint if exists erp_employees_contract_dates_check;
alter table public.erp_employees add constraint erp_employees_contract_dates_check
  check (contract_start_date is null or contract_end_date is null or contract_end_date >= contract_start_date);

-- Add central administration beneath executive management for each company.
do $$
declare c record; v_parent uuid;
begin
  for c in select id from public.erp_companies loop
    select id into v_parent from public.erp_hr_departments where company_id = c.id and department_code = 'DIR-001';
    if v_parent is not null then
      insert into public.erp_hr_departments(company_id,department_code,name_ar,name_en,parent_id,department_level)
      values(c.id,'DIR-SEC-CENTRAL','الإدارة المركزية','Central Administration',v_parent,'department')
      on conflict(company_id,department_code) do nothing;
    end if;
  end loop;
end $$;