create table if not exists public.erp_hr_employee_custodies (
  id uuid primary key default gen_random_uuid(),
  company_id uuid not null references public.erp_companies(id) on delete cascade,
  employee_id uuid not null references public.erp_employees(id) on delete restrict,
  custody_code text not null,
  item_name text not null,
  category text,
  serial_number text,
  assigned_on date not null default current_date,
  expected_return_on date,
  returned_on date,
  status text not null default 'assigned'
    check (status in ('assigned','returned','lost','damaged')),
  condition_on_issue text,
  condition_on_return text,
  notes text,
  created_by uuid references auth.users(id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint erp_hr_employee_custodies_code_unique unique (company_id, custody_code),
  constraint erp_hr_employee_custodies_expected_return_check
    check (expected_return_on is null or expected_return_on >= assigned_on),
  constraint erp_hr_employee_custodies_returned_check
    check (returned_on is null or returned_on >= assigned_on)
);

create index if not exists erp_hr_employee_custodies_company_employee_idx
  on public.erp_hr_employee_custodies(company_id, employee_id, status);

alter table public.erp_hr_employee_custodies enable row level security;

drop policy if exists erp_hr_employee_custodies_select_hr on public.erp_hr_employee_custodies;
create policy erp_hr_employee_custodies_select_hr
on public.erp_hr_employee_custodies for select to authenticated
using (
  public.erp_user_has_company_role(company_id, array['owner','admin','manager']::text[])
  or exists (
    select 1 from public.erp_company_member_profiles p
    where p.company_id = erp_hr_employee_custodies.company_id
      and p.user_id = (select auth.uid())
      and trim(coalesce(p.job_title,'')) in ('مدير موارد بشرية','مسئول موارد بشرية','مسؤول موارد بشرية')
  )
);

drop policy if exists erp_hr_employee_custodies_insert_hr on public.erp_hr_employee_custodies;
create policy erp_hr_employee_custodies_insert_hr
on public.erp_hr_employee_custodies for insert to authenticated
with check (
  public.erp_user_has_company_role(company_id, array['owner','admin','manager']::text[])
  or exists (
    select 1 from public.erp_company_member_profiles p
    where p.company_id = erp_hr_employee_custodies.company_id
      and p.user_id = (select auth.uid())
      and trim(coalesce(p.job_title,'')) in ('مدير موارد بشرية','مسئول موارد بشرية','مسؤول موارد بشرية')
  )
);

drop policy if exists erp_hr_employee_custodies_update_hr on public.erp_hr_employee_custodies;
create policy erp_hr_employee_custodies_update_hr
on public.erp_hr_employee_custodies for update to authenticated
using (
  public.erp_user_has_company_role(company_id, array['owner','admin','manager']::text[])
  or exists (
    select 1 from public.erp_company_member_profiles p
    where p.company_id = erp_hr_employee_custodies.company_id
      and p.user_id = (select auth.uid())
      and trim(coalesce(p.job_title,'')) in ('مدير موارد بشرية','مسئول موارد بشرية','مسؤول موارد بشرية')
  )
)
with check (
  public.erp_user_has_company_role(company_id, array['owner','admin','manager']::text[])
  or exists (
    select 1 from public.erp_company_member_profiles p
    where p.company_id = erp_hr_employee_custodies.company_id
      and p.user_id = (select auth.uid())
      and trim(coalesce(p.job_title,'')) in ('مدير موارد بشرية','مسئول موارد بشرية','مسؤول موارد بشرية')
  )
);

drop policy if exists erp_hr_employee_custodies_delete_hr on public.erp_hr_employee_custodies;
create policy erp_hr_employee_custodies_delete_hr
on public.erp_hr_employee_custodies for delete to authenticated
using (
  public.erp_user_has_company_role(company_id, array['owner','admin']::text[])
  or exists (
    select 1 from public.erp_company_member_profiles p
    where p.company_id = erp_hr_employee_custodies.company_id
      and p.user_id = (select auth.uid())
      and trim(coalesce(p.job_title,'')) = 'مدير موارد بشرية'
  )
);

grant select, insert, update, delete on public.erp_hr_employee_custodies to authenticated;
