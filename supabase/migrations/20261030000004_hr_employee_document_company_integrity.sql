create unique index if not exists erp_employees_id_company_uidx
  on public.erp_employees(id, company_id);

do $$
begin
  if not exists (
    select 1 from pg_constraint
    where conrelid = 'public.erp_employee_documents'::regclass
      and conname = 'erp_employee_documents_employee_company_fk'
  ) then
    alter table public.erp_employee_documents
      add constraint erp_employee_documents_employee_company_fk
      foreign key (employee_id, company_id)
      references public.erp_employees(id, company_id)
      on delete cascade;
  end if;
end $$;
