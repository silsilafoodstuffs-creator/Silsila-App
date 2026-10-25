create table if not exists public.erp_employee_monthly_targets (
  id uuid primary key default gen_random_uuid(),
  company_id uuid not null references public.erp_companies(id) on delete cascade,
  employee_id uuid not null references public.erp_employees(id) on delete cascade,
  target_type text not null check (target_type in ('sales','purchase')),
  target_month date not null,
  target_amount numeric(14,2) not null default 0 check (target_amount >= 0),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint erp_employee_monthly_targets_unique unique(company_id,employee_id,target_type,target_month)
);
create index if not exists idx_erp_employee_monthly_targets_month on public.erp_employee_monthly_targets(company_id,target_type,target_month);
alter table public.erp_employee_monthly_targets enable row level security;
drop policy if exists erp_employee_monthly_targets_company_access on public.erp_employee_monthly_targets;
create policy erp_employee_monthly_targets_company_access on public.erp_employee_monthly_targets for all to authenticated using (public.erp_user_can_access_company(company_id)) with check (public.erp_user_can_access_company(company_id));
