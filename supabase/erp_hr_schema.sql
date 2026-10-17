-- Silsila ERP HR foundation: employee directory, attendance, leave and payroll runs.
-- Apply after erp_schema.sql. Access remains closed until membership RLS policies are applied.

create table if not exists public.erp_employees (
  id uuid primary key default gen_random_uuid(),
  company_id uuid not null references public.erp_companies(id) on delete restrict,
  branch_id uuid references public.erp_branches(id) on delete restrict,
  employee_code text not null,
  full_name text not null,
  phone text,
  email text,
  job_title text,
  department_name text,
  hire_date date,
  employment_status text not null default 'active'
    check (employment_status in ('active','on_leave','suspended','terminated')),
  base_salary numeric(14,2) not null default 0 check (base_salary >= 0),
  national_id_last4 text,
  notes text,
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique(company_id, employee_code),
  check (length(trim(full_name)) > 0)
);

create table if not exists public.erp_attendance_records (
  id uuid primary key default gen_random_uuid(),
  company_id uuid not null references public.erp_companies(id) on delete restrict,
  employee_id uuid not null references public.erp_employees(id) on delete restrict,
  work_date date not null,
  check_in timestamptz,
  check_out timestamptz,
  attendance_status text not null default 'present'
    check (attendance_status in ('present','late','absent','excused','remote','holiday')),
  late_minutes integer not null default 0 check (late_minutes >= 0),
  overtime_minutes integer not null default 0 check (overtime_minutes >= 0),
  notes text,
  recorded_by uuid references auth.users(id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique(employee_id, work_date),
  check (check_out is null or check_in is null or check_out >= check_in)
);

create table if not exists public.erp_leave_requests (
  id uuid primary key default gen_random_uuid(),
  company_id uuid not null references public.erp_companies(id) on delete restrict,
  employee_id uuid not null references public.erp_employees(id) on delete restrict,
  leave_type text not null,
  starts_on date not null,
  ends_on date not null,
  requested_days numeric(8,2) not null check (requested_days > 0),
  reason text,
  status text not null default 'pending'
    check (status in ('pending','approved','rejected','cancelled')),
  approved_by uuid references auth.users(id) on delete set null,
  approved_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  check (ends_on >= starts_on)
);

create table if not exists public.erp_payroll_runs (
  id uuid primary key default gen_random_uuid(),
  company_id uuid not null references public.erp_companies(id) on delete restrict,
  run_code text not null,
  period_start date not null,
  period_end date not null,
  status text not null default 'draft'
    check (status in ('draft','approved','posted','paid','cancelled')),
  employee_count integer not null default 0 check (employee_count >= 0),
  gross_total numeric(16,2) not null default 0 check (gross_total >= 0),
  deduction_total numeric(16,2) not null default 0 check (deduction_total >= 0),
  net_total numeric(16,2) not null default 0 check (net_total >= 0),
  expense_account_id uuid references public.erp_accounts(id) on delete restrict,
  payable_account_id uuid references public.erp_accounts(id) on delete restrict,
  deductions_account_id uuid references public.erp_accounts(id) on delete restrict,
  journal_entry_id uuid references public.erp_journal_entries(id) on delete restrict,
  notes text,
  created_by uuid references auth.users(id) on delete set null,
  approved_by uuid references auth.users(id) on delete set null,
  approved_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique(company_id, run_code),
  check (period_end >= period_start),
  check (net_total = gross_total - deduction_total)
);

create table if not exists public.erp_payroll_lines (
  id uuid primary key default gen_random_uuid(),
  company_id uuid not null references public.erp_companies(id) on delete restrict,
  payroll_run_id uuid not null references public.erp_payroll_runs(id) on delete cascade,
  employee_id uuid not null references public.erp_employees(id) on delete restrict,
  basic_amount numeric(14,2) not null default 0 check (basic_amount >= 0),
  allowances numeric(14,2) not null default 0 check (allowances >= 0),
  commissions numeric(14,2) not null default 0 check (commissions >= 0),
  overtime_amount numeric(14,2) not null default 0 check (overtime_amount >= 0),
  deductions numeric(14,2) not null default 0 check (deductions >= 0),
  gross_amount numeric(14,2) not null default 0 check (gross_amount >= 0),
  net_amount numeric(14,2) not null default 0 check (net_amount >= 0),
  notes text,
  created_at timestamptz not null default now(),
  unique(payroll_run_id, employee_id),
  check (gross_amount = basic_amount + allowances + commissions + overtime_amount),
  check (net_amount = gross_amount - deductions)
);

create index if not exists erp_employees_company_status_idx
  on public.erp_employees(company_id, employment_status, employee_code);
create index if not exists erp_attendance_company_date_idx
  on public.erp_attendance_records(company_id, work_date);
create index if not exists erp_leave_company_dates_idx
  on public.erp_leave_requests(company_id, starts_on, ends_on);
create index if not exists erp_payroll_period_idx
  on public.erp_payroll_runs(company_id, period_start, period_end);
create index if not exists erp_payroll_lines_employee_idx
  on public.erp_payroll_lines(company_id, employee_id);

alter table public.erp_employees enable row level security;
alter table public.erp_attendance_records enable row level security;
alter table public.erp_leave_requests enable row level security;
alter table public.erp_payroll_runs enable row level security;
alter table public.erp_payroll_lines enable row level security;

do $$
declare t text;
begin
  foreach t in array array['erp_employees','erp_attendance_records','erp_leave_requests','erp_payroll_runs']
  loop
    execute format('drop trigger if exists %I on public.%I', t || '_updated_at', t);
    execute format('create trigger %I before update on public.%I for each row execute function public.erp_set_updated_at()', t || '_updated_at', t);
  end loop;
end;
$$;


-- Database-level tenant integrity: do not rely only on Flutter validation.
create or replace function public.erp_validate_hr_company_links()
returns trigger
language plpgsql
security invoker
set search_path = public
as $$
declare
  v_employee_company uuid;
  v_branch_company uuid;
  v_run_company uuid;
begin
  if tg_table_name = 'erp_employees' then
    if new.branch_id is not null then
      select company_id into v_branch_company from public.erp_branches where id = new.branch_id;
      if v_branch_company is distinct from new.company_id then
        raise exception 'فرع الموظف يجب أن يتبع الشركة نفسها';
      end if;
    end if;
  elsif tg_table_name in ('erp_attendance_records','erp_leave_requests') then
    select company_id into v_employee_company from public.erp_employees where id = new.employee_id;
    if v_employee_company is distinct from new.company_id then
      raise exception 'الموظف يجب أن يتبع شركة السجل نفسه';
    end if;
  elsif tg_table_name = 'erp_payroll_lines' then
    select company_id into v_employee_company from public.erp_employees where id = new.employee_id;
    select company_id into v_run_company from public.erp_payroll_runs where id = new.payroll_run_id;
    if v_employee_company is distinct from new.company_id
       or v_run_company is distinct from new.company_id then
      raise exception 'الموظف ومسير الرواتب يجب أن يتبعوا الشركة نفسها';
    end if;
  end if;
  return new;
end;
$$;

drop trigger if exists erp_employees_company_guard on public.erp_employees;
create trigger erp_employees_company_guard before insert or update of company_id, branch_id
on public.erp_employees for each row execute function public.erp_validate_hr_company_links();

drop trigger if exists erp_attendance_company_guard on public.erp_attendance_records;
create trigger erp_attendance_company_guard before insert or update of company_id, employee_id
on public.erp_attendance_records for each row execute function public.erp_validate_hr_company_links();

drop trigger if exists erp_leave_company_guard on public.erp_leave_requests;
create trigger erp_leave_company_guard before insert or update of company_id, employee_id
on public.erp_leave_requests for each row execute function public.erp_validate_hr_company_links();

drop trigger if exists erp_payroll_line_company_guard on public.erp_payroll_lines;
create trigger erp_payroll_line_company_guard before insert or update of company_id, employee_id, payroll_run_id
on public.erp_payroll_lines for each row execute function public.erp_validate_hr_company_links();


-- No direct access grants are added here. Apply membership-aware policies and
-- role grants only after reviewing the target company's HR access requirements.
