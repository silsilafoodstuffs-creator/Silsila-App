begin;
create table if not exists public.erp_hr_end_of_service_settlements (
 id uuid primary key default gen_random_uuid(),
 company_id uuid not null references public.erp_companies(id) on delete cascade,
 employee_id uuid not null references public.erp_employees(id) on delete cascade,
 service_start_date date, separation_date date not null default current_date,
 basic_salary_snapshot numeric(14,2) not null default 0 check(basic_salary_snapshot>=0),
 accrued_leave_amount numeric(14,2) not null default 0 check(accrued_leave_amount>=0),
 other_entitlements numeric(14,2) not null default 0 check(other_entitlements>=0),
 outstanding_advances numeric(14,2) not null default 0 check(outstanding_advances>=0),
 other_deductions numeric(14,2) not null default 0 check(other_deductions>=0),
 total_entitlements numeric(14,2) not null default 0 check(total_entitlements>=0),
 net_amount numeric(14,2) not null default 0 check(net_amount>=0),
 reason text not null,
 status text not null default 'pending' check(status=any(array['pending','approved','rejected','paid']::text[])),
 approved_by uuid, approved_at timestamptz, paid_at timestamptz,
 notes text, created_by uuid default auth.uid(),
 created_at timestamptz not null default now(), updated_at timestamptz not null default now()
);
alter table public.erp_hr_end_of_service_settlements enable row level security;
create policy erp_hr_end_of_service_select_hr on public.erp_hr_end_of_service_settlements for select to authenticated using (
 public.erp_user_has_company_role(company_id,array['owner','admin','manager'])
 or exists(select 1 from public.erp_company_member_profiles p where p.company_id=public.erp_hr_end_of_service_settlements.company_id and p.user_id=(select auth.uid())
  and trim(coalesce(p.job_title,chr(32))) in ('مدير موارد بشرية','مسئول موارد بشرية','مسؤول موارد بشرية'))
);
create policy erp_hr_end_of_service_insert_hr on public.erp_hr_end_of_service_settlements for insert to authenticated with check (
 public.erp_user_has_company_role(company_id,array['owner','admin','manager'])
 or exists(select 1 from public.erp_company_member_profiles p where p.company_id=public.erp_hr_end_of_service_settlements.company_id and p.user_id=(select auth.uid())
  and trim(coalesce(p.job_title,chr(32))) in ('مدير موارد بشرية','مسئول موارد بشرية','مسؤول موارد بشرية'))
);
create policy erp_hr_end_of_service_update_hr on public.erp_hr_end_of_service_settlements for update to authenticated using (
 public.erp_user_has_company_role(company_id,array['owner','admin','manager'])
 or exists(select 1 from public.erp_company_member_profiles p where p.company_id=public.erp_hr_end_of_service_settlements.company_id and p.user_id=(select auth.uid())
  and trim(coalesce(p.job_title,chr(32))) in ('مدير موارد بشرية','مسئول موارد بشرية','مسؤول موارد بشرية'))
) with check (
 public.erp_user_has_company_role(company_id,array['owner','admin','manager'])
 or exists(select 1 from public.erp_company_member_profiles p where p.company_id=public.erp_hr_end_of_service_settlements.company_id and p.user_id=(select auth.uid())
  and trim(coalesce(p.job_title,chr(32))) in ('مدير موارد بشرية','مسئول موارد بشرية','مسؤول موارد بشرية'))
);
create policy erp_hr_end_of_service_delete_hr on public.erp_hr_end_of_service_settlements for delete to authenticated using (public.erp_user_has_company_role(company_id,array['owner','admin']));
create trigger erp_hr_end_of_service_company_link before insert or update of company_id,employee_id
on public.erp_hr_end_of_service_settlements for each row execute function public.erp_hr_validate_company_links();
create trigger erp_hr_end_of_service_updated_at before update
on public.erp_hr_end_of_service_settlements for each row execute function public.erp_set_updated_at();
create index if not exists idx_hr_end_service_company_employee_date on public.erp_hr_end_of_service_settlements(company_id,employee_id,separation_date desc);
commit;
