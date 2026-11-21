begin;

alter table public.erp_hr_employee_movements
  add column if not exists target_branch_id uuid references public.erp_branches(id) on delete set null,
  add column if not exists target_department_id uuid references public.erp_hr_departments(id) on delete set null,
  add column if not exists target_job_id uuid references public.erp_hr_jobs(id) on delete set null;

alter table public.erp_hr_employee_movements
  drop constraint if exists erp_hr_employee_movements_movement_type_check;

alter table public.erp_hr_employee_movements
  add constraint erp_hr_employee_movements_movement_type_check
  check (movement_type = any (array[
    'hire','resignation','termination','retirement','transfer',
    'promotion','suspension','return_to_work'
  ]::text[]));

create or replace function public.erp_hr_validate_company_links()
returns trigger
language plpgsql
set search_path = public
as $function$
begin
  if tg_table_name = 'erp_hr_recruitment_candidates' then
    if new.job_id is not null and not exists (
      select 1 from public.erp_hr_jobs j
      where j.id = new.job_id and j.company_id = new.company_id
    ) then
      raise exception 'الوظيفة المحددة لا تتبع الشركة الحالية.';
    end if;
  elsif tg_table_name = 'erp_hr_employee_movements' then
    if not exists (
      select 1 from public.erp_employees e
      where e.id = new.employee_id and e.company_id = new.company_id
    ) then
      raise exception 'الموظف المحدد لا يتبع الشركة الحالية.';
    end if;
    if new.target_branch_id is not null and not exists (
      select 1 from public.erp_branches b
      where b.id = new.target_branch_id and b.company_id = new.company_id
    ) then
      raise exception 'الفرع المحدد لا يتبع الشركة الحالية.';
    end if;
    if new.target_department_id is not null and not exists (
      select 1 from public.erp_hr_departments d
      where d.id = new.target_department_id and d.company_id = new.company_id
    ) then
      raise exception 'الإدارة المحددة لا تتبع الشركة الحالية.';
    end if;
    if new.target_job_id is not null and not exists (
      select 1 from public.erp_hr_jobs j
      where j.id = new.target_job_id and j.company_id = new.company_id
    ) then
      raise exception 'الوظيفة المحددة لا تتبع الشركة الحالية.';
    end if;
  else
    if not exists (
      select 1 from public.erp_employees e
      where e.id = new.employee_id and e.company_id = new.company_id
    ) then
      raise exception 'الموظف المحدد لا يتبع الشركة الحالية.';
    end if;
  end if;
  return new;
end;
$function$;

create or replace function public.erp_hr_apply_employee_movement()
returns trigger
language plpgsql
set search_path = public
as $function$
declare
  today_local date := (now() at time zone 'Africa/Cairo')::date;
  latest_effective_date date;
begin
  if new.effective_on > today_local then
    return new;
  end if;

  select max(m.effective_on)
    into latest_effective_date
    from public.erp_hr_employee_movements m
   where m.company_id = new.company_id
     and m.employee_id = new.employee_id
     and m.effective_on <= today_local;

  if latest_effective_date is distinct from new.effective_on then
    return new;
  end if;

  if new.movement_type in ('resignation','termination','retirement') then
    update public.erp_employees
       set is_active=false, employment_status='terminated', updated_at=now()
     where id=new.employee_id and company_id=new.company_id;
  elsif new.movement_type in ('return_to_work','hire') then
    update public.erp_employees
       set is_active=true, employment_status='active', updated_at=now()
     where id=new.employee_id and company_id=new.company_id;
  elsif new.movement_type='suspension' then
    update public.erp_employees
       set is_active=true, employment_status='suspended', updated_at=now()
     where id=new.employee_id and company_id=new.company_id;
  elsif new.movement_type in ('transfer','promotion') then
    update public.erp_employees e
       set branch_id=coalesce(new.target_branch_id,e.branch_id),
           department_id=coalesce(new.target_department_id,e.department_id),
           job_id=coalesce(new.target_job_id,e.job_id),
           department_name=coalesce((select d.name_ar from public.erp_hr_departments d where d.id=new.target_department_id and d.company_id=new.company_id),e.department_name),
           job_title=coalesce((select j.name_ar from public.erp_hr_jobs j where j.id=new.target_job_id and j.company_id=new.company_id),e.job_title),
           updated_at=now()
     where e.id=new.employee_id and e.company_id=new.company_id;
  end if;
  return new;
end;
$function$;

commit;
