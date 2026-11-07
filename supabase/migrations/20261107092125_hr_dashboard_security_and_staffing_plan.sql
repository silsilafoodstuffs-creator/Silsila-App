begin;

-- Sensitive HR tables must never be directly accessible to anonymous clients.
revoke all privileges on table
  public.erp_employees,
  public.erp_hr_attendance_events,
  public.erp_hr_departments,
  public.erp_hr_employee_actions,
  public.erp_hr_employee_advances,
  public.erp_hr_employee_compliance,
  public.erp_hr_employee_contracts,
  public.erp_hr_employee_custodies,
  public.erp_hr_employee_movements,
  public.erp_hr_end_of_service_settlements,
  public.erp_hr_fingerprint_devices,
  public.erp_hr_job_grades,
  public.erp_hr_jobs,
  public.erp_hr_overtime_requests,
  public.erp_hr_performance_reviews,
  public.erp_hr_recruitment_candidates,
  public.erp_hr_reference_catalogs,
  public.erp_hr_salary_elements,
  public.erp_hr_shift_assignments,
  public.erp_hr_shifts,
  public.erp_hr_training_records,
  public.erp_hr_work_locations
from anon;

alter policy erp_employees_select_hr on public.erp_employees to authenticated;
alter policy erp_employees_update_hr on public.erp_employees to authenticated;

-- Keep the approved public identity projection read-only.
revoke all privileges on table public.profile_public_directory from public, anon, authenticated;
grant select on table public.profile_public_directory to anon, authenticated;
alter view public.profile_public_directory set (security_invoker = false);
comment on view public.profile_public_directory is
  'Read-only public identity projection for approved marketplace participants. Never grant write privileges; excludes platform-management accounts.';

create table if not exists public.erp_hr_staffing_plans (
  id uuid primary key default gen_random_uuid(),
  company_id uuid not null references public.erp_companies(id) on delete cascade,
  job_id uuid not null references public.erp_hr_jobs(id) on delete restrict,
  work_location_id uuid references public.erp_hr_work_locations(id) on delete restrict,
  authorized_headcount integer not null check (authorized_headcount >= 0),
  effective_from date not null default current_date,
  effective_to date,
  status text not null default 'draft'
    check (status in ('draft','pending_approval','approved','rejected','cancelled')),
  notes text,
  created_by uuid default auth.uid(),
  approved_by uuid,
  approved_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  check (effective_to is null or effective_to >= effective_from)
);

create index if not exists idx_hr_staffing_company_status_dates
  on public.erp_hr_staffing_plans(company_id,status,effective_from,effective_to);
create index if not exists idx_hr_staffing_job_location
  on public.erp_hr_staffing_plans(company_id,job_id,work_location_id);

alter table public.erp_hr_staffing_plans enable row level security;
revoke all privileges on table public.erp_hr_staffing_plans from public, anon;
grant select, insert, update, delete on table public.erp_hr_staffing_plans to authenticated;

create or replace function public.erp_hr_validate_staffing_plan()
returns trigger
language plpgsql
security definer
set search_path = ''
set row_security = 'off'
as $function$
begin
  if not exists (
    select 1 from public.erp_hr_jobs j
    where j.id = new.job_id and j.company_id = new.company_id
  ) then
    raise exception 'الوظيفة المحددة لا تتبع الشركة الحالية.';
  end if;

  if new.work_location_id is not null and not exists (
    select 1 from public.erp_hr_work_locations w
    where w.id = new.work_location_id and w.company_id = new.company_id
  ) then
    raise exception 'موقع العمل المحدد لا يتبع الشركة الحالية.';
  end if;

  if new.status = 'approved' then
    if new.approved_by is null then
      new.approved_by := auth.uid();
    end if;
    if new.approved_at is null then
      new.approved_at := now();
    end if;

    if exists (
      select 1
      from public.erp_hr_staffing_plans p
      where p.company_id = new.company_id
        and p.job_id = new.job_id
        and p.work_location_id is not distinct from new.work_location_id
        and p.status = 'approved'
        and p.id is distinct from new.id
        and daterange(p.effective_from, coalesce(p.effective_to, 'infinity'::date), '[)')
            && daterange(new.effective_from, coalesce(new.effective_to, 'infinity'::date), '[)')
    ) then
      raise exception 'توجد خطة ملاك معتمدة متداخلة لنفس الوظيفة وموقع العمل.';
    end if;
  else
    new.approved_by := null;
    new.approved_at := null;
  end if;

  new.updated_at := now();
  return new;
end;
$function$;

revoke all on function public.erp_hr_validate_staffing_plan() from public, anon, authenticated;
drop trigger if exists trg_erp_hr_validate_staffing_plan on public.erp_hr_staffing_plans;
create trigger trg_erp_hr_validate_staffing_plan
before insert or update on public.erp_hr_staffing_plans
for each row execute function public.erp_hr_validate_staffing_plan();

drop policy if exists erp_hr_staffing_plans_select_company on public.erp_hr_staffing_plans;
create policy erp_hr_staffing_plans_select_company
on public.erp_hr_staffing_plans for select to authenticated
using (public.erp_user_can_access_company(company_id));

drop policy if exists erp_hr_staffing_plans_insert_hr on public.erp_hr_staffing_plans;
create policy erp_hr_staffing_plans_insert_hr
on public.erp_hr_staffing_plans for insert to authenticated
with check (
  public.erp_user_has_company_role(company_id, array['owner','admin','manager'])
  or exists (
    select 1 from public.erp_company_member_profiles p
    where p.company_id = erp_hr_staffing_plans.company_id
      and p.user_id = (select auth.uid())
      and btrim(coalesce(p.job_title,'')) = 'مدير موارد بشرية'
  )
);

drop policy if exists erp_hr_staffing_plans_update_hr on public.erp_hr_staffing_plans;
create policy erp_hr_staffing_plans_update_hr
on public.erp_hr_staffing_plans for update to authenticated
using (
  public.erp_user_has_company_role(company_id, array['owner','admin','manager'])
  or exists (
    select 1 from public.erp_company_member_profiles p
    where p.company_id = erp_hr_staffing_plans.company_id
      and p.user_id = (select auth.uid())
      and btrim(coalesce(p.job_title,'')) = 'مدير موارد بشرية'
  )
)
with check (
  public.erp_user_has_company_role(company_id, array['owner','admin','manager'])
  or exists (
    select 1 from public.erp_company_member_profiles p
    where p.company_id = erp_hr_staffing_plans.company_id
      and p.user_id = (select auth.uid())
      and btrim(coalesce(p.job_title,'')) = 'مدير موارد بشرية'
  )
);

drop policy if exists erp_hr_staffing_plans_delete_hr on public.erp_hr_staffing_plans;
create policy erp_hr_staffing_plans_delete_hr
on public.erp_hr_staffing_plans for delete to authenticated
using (
  public.erp_user_has_company_role(company_id, array['owner','admin','manager'])
  or exists (
    select 1 from public.erp_company_member_profiles p
    where p.company_id = erp_hr_staffing_plans.company_id
      and p.user_id = (select auth.uid())
      and btrim(coalesce(p.job_title,'')) = 'مدير موارد بشرية'
  )
);

comment on table public.erp_hr_staffing_plans is
  'Approved authorized headcount by job and work location. Vacancies are calculated against current non-seed employees; draft and pending plans are excluded.';

commit;
