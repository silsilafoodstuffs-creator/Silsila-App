begin;
create table if not exists public.erp_hr_employee_contracts (
 id uuid primary key default gen_random_uuid(),
 company_id uuid not null references public.erp_companies(id) on delete cascade,
 employee_id uuid not null references public.erp_employees(id) on delete cascade,
 contract_number text,
 contract_type text not null check(contract_type=any(array['بعقد','بدون عقد','شركة عمالة','مؤقت','يومية']::text[])),
 start_date date not null, end_date date,
 salary numeric(14,2) not null default 0 check(salary>=0),
 status text not null default 'draft' check(status=any(array['draft','active','expired','terminated']::text[])),
 notes text, created_by uuid default auth.uid(),
 created_at timestamptz not null default now(), updated_at timestamptz not null default now(),
 check(end_date is null or end_date>=start_date)
);
alter table public.erp_hr_employee_contracts enable row level security;
create policy erp_hr_employee_contracts_select_hr on public.erp_hr_employee_contracts
for select to authenticated using (
 public.erp_user_has_company_role(company_id,array['owner','admin','manager'])
 or exists(select 1 from public.erp_company_member_profiles p where p.company_id=public.erp_hr_employee_contracts.company_id
  and p.user_id=(select auth.uid()) and trim(coalesce(p.job_title,chr(32))) in ('مدير موارد بشرية','مسئول موارد بشرية','مسؤول موارد بشرية'))
);
create policy erp_hr_employee_contracts_insert_hr on public.erp_hr_employee_contracts
for insert to authenticated with check (
 public.erp_user_has_company_role(company_id,array['owner','admin','manager'])
 or exists(select 1 from public.erp_company_member_profiles p where p.company_id=public.erp_hr_employee_contracts.company_id
  and p.user_id=(select auth.uid()) and trim(coalesce(p.job_title,chr(32))) in ('مدير موارد بشرية','مسئول موارد بشرية','مسؤول موارد بشرية'))
);
create policy erp_hr_employee_contracts_update_hr on public.erp_hr_employee_contracts
for update to authenticated using (
 public.erp_user_has_company_role(company_id,array['owner','admin','manager'])
 or exists(select 1 from public.erp_company_member_profiles p where p.company_id=public.erp_hr_employee_contracts.company_id
  and p.user_id=(select auth.uid()) and trim(coalesce(p.job_title,chr(32))) in ('مدير موارد بشرية','مسئول موارد بشرية','مسؤول موارد بشرية'))
) with check (
 public.erp_user_has_company_role(company_id,array['owner','admin','manager'])
 or exists(select 1 from public.erp_company_member_profiles p where p.company_id=public.erp_hr_employee_contracts.company_id
  and p.user_id=(select auth.uid()) and trim(coalesce(p.job_title,chr(32))) in ('مدير موارد بشرية','مسئول موارد بشرية','مسؤول موارد بشرية'))
);
create policy erp_hr_employee_contracts_delete_hr on public.erp_hr_employee_contracts
for delete to authenticated using (public.erp_user_has_company_role(company_id,array['owner','admin']));
create trigger erp_hr_employee_contracts_company_link before insert or update of company_id,employee_id
on public.erp_hr_employee_contracts for each row execute function public.erp_hr_validate_company_links();
create trigger erp_hr_employee_contracts_updated_at before update
on public.erp_hr_employee_contracts for each row execute function public.erp_set_updated_at();
create index if not exists idx_hr_contracts_company_employee_dates on public.erp_hr_employee_contracts(company_id,employee_id,start_date desc);
commit;
