begin;

create table if not exists public.erp_hr_employee_advances (
  id uuid primary key default gen_random_uuid(),
  company_id uuid not null references public.erp_companies(id) on delete cascade,
  employee_id uuid not null references public.erp_employees(id) on delete cascade,
  advance_number text,
  requested_on date not null default current_date,
  amount numeric(14,2) not null check (amount > 0),
  installments integer not null default 1 check (installments > 0),
  installment_amount numeric(14,2) not null default 0 check (installment_amount >= 0),
  reason text not null,
  status text not null default 'pending' check (status = any(array['pending','approved','rejected','disbursed','settled']::text[])),
  approved_by uuid, approved_at timestamptz, disbursed_at timestamptz, settled_at timestamptz,
  settled_amount numeric(14,2) not null default 0 check (settled_amount >= 0 and settled_amount <= amount),
  notes text, created_by uuid default auth.uid(),
  created_at timestamptz not null default now(), updated_at timestamptz not null default now()
);

create table if not exists public.erp_hr_employee_actions (
  id uuid primary key default gen_random_uuid(),
  company_id uuid not null references public.erp_companies(id) on delete cascade,
  employee_id uuid not null references public.erp_employees(id) on delete cascade,
  action_type text not null check (action_type = any(array['penalty','reward']::text[])),
  action_date date not null default current_date,
  amount numeric(14,2) not null default 0 check (amount >= 0),
  reason text not null,
  status text not null default 'pending' check (status = any(array['pending','approved','rejected','applied']::text[])),
  approved_by uuid, approved_at timestamptz, notes text,
  created_by uuid default auth.uid(),
  created_at timestamptz not null default now(), updated_at timestamptz not null default now()
);

create table if not exists public.erp_hr_overtime_requests (
  id uuid primary key default gen_random_uuid(),
  company_id uuid not null references public.erp_companies(id) on delete cascade,
  employee_id uuid not null references public.erp_employees(id) on delete cascade,
  work_date date not null,
  hours numeric(8,2) not null check (hours > 0),
  hourly_rate numeric(12,2) not null default 0 check (hourly_rate >= 0),
  amount numeric(14,2) not null default 0 check (amount >= 0),
  reason text not null,
  status text not null default 'pending' check (status = any(array['pending','approved','rejected','paid']::text[])),
  approved_by uuid, approved_at timestamptz, notes text,
  created_by uuid default auth.uid(),
  created_at timestamptz not null default now(), updated_at timestamptz not null default now()
);

create table if not exists public.erp_hr_performance_reviews (
  id uuid primary key default gen_random_uuid(),
  company_id uuid not null references public.erp_companies(id) on delete cascade,
  employee_id uuid not null references public.erp_employees(id) on delete cascade,
  period_start date not null,
  period_end date not null,
  score numeric(5,2) not null check (score >= 0 and score <= 100),
  rating text, strengths text, improvement_areas text, goals text,
  status text not null default 'draft' check (status = any(array['draft','submitted','approved','rejected']::text[])),
  reviewer_user_id uuid default auth.uid(), approved_by uuid, approved_at timestamptz,
  created_at timestamptz not null default now(), updated_at timestamptz not null default now(),
  check (period_end >= period_start)
);

do $$
declare t text;
begin
  foreach t in array array[
    'erp_hr_employee_advances','erp_hr_employee_actions',
    'erp_hr_overtime_requests','erp_hr_performance_reviews'
  ] loop
    execute format('alter table public.%I enable row level security',t);
    execute format('drop policy if exists %I on public.%I',t||'_select_hr',t);
    execute format('create policy %I on public.%I for select to authenticated using (
      public.erp_user_has_company_role(company_id, array[''owner'',''admin'',''manager''])
      or exists (select 1 from public.erp_company_member_profiles p
        where p.company_id = public.%I.company_id and p.user_id = (select auth.uid())
          and trim(coalesce(p.job_title, chr(32))) in (''مدير موارد بشرية'',''مسئول موارد بشرية'',''مسؤول موارد بشرية''))
    )',t||'_select_hr',t,t);
    execute format('drop policy if exists %I on public.%I',t||'_insert_hr',t);
    execute format('create policy %I on public.%I for insert to authenticated with check (
      public.erp_user_has_company_role(company_id, array[''owner'',''admin'',''manager''])
      or exists (select 1 from public.erp_company_member_profiles p
        where p.company_id = public.%I.company_id and p.user_id = (select auth.uid())
          and trim(coalesce(p.job_title, chr(32))) in (''مدير موارد بشرية'',''مسئول موارد بشرية'',''مسؤول موارد بشرية''))
    )',t||'_insert_hr',t,t);
    execute format('drop policy if exists %I on public.%I',t||'_update_hr',t);
    execute format('create policy %I on public.%I for update to authenticated using (
      public.erp_user_has_company_role(company_id, array[''owner'',''admin'',''manager''])
      or exists (select 1 from public.erp_company_member_profiles p
        where p.company_id = public.%I.company_id and p.user_id = (select auth.uid())
          and trim(coalesce(p.job_title, chr(32))) in (''مدير موارد بشرية'',''مسئول موارد بشرية'',''مسؤول موارد بشرية''))
    ) with check (
      public.erp_user_has_company_role(company_id, array[''owner'',''admin'',''manager''])
      or exists (select 1 from public.erp_company_member_profiles p
        where p.company_id = public.%I.company_id and p.user_id = (select auth.uid())
          and trim(coalesce(p.job_title, chr(32))) in (''مدير موارد بشرية'',''مسئول موارد بشرية'',''مسؤول موارد بشرية''))
    )',t||'_update_hr',t,t,t);
    execute format('drop policy if exists %I on public.%I',t||'_delete_hr',t);
    execute format('create policy %I on public.%I for delete to authenticated using (
      public.erp_user_has_company_role(company_id, array[''owner'',''admin''])
      or exists (select 1 from public.erp_company_member_profiles p
        where p.company_id = public.%I.company_id and p.user_id = (select auth.uid())
          and trim(coalesce(p.job_title, chr(32))) = ''مدير موارد بشرية'')
    )',t||'_delete_hr',t,t);
    execute format('drop trigger if exists %I on public.%I',t||'_company_link',t);
    execute format('create trigger %I before insert or update of company_id,employee_id on public.%I
      for each row execute function public.erp_hr_validate_company_links()',t||'_company_link',t);
    execute format('drop trigger if exists %I on public.%I',t||'_updated_at',t);
    execute format('create trigger %I before update on public.%I
      for each row execute function public.erp_set_updated_at()',t||'_updated_at',t);
  end loop;
end $$;

create index if not exists idx_hr_advances_company_employee_date on public.erp_hr_employee_advances(company_id,employee_id,requested_on desc);
create index if not exists idx_hr_actions_company_employee_date on public.erp_hr_employee_actions(company_id,employee_id,action_date desc);
create index if not exists idx_hr_overtime_company_date on public.erp_hr_overtime_requests(company_id,work_date desc);
create index if not exists idx_hr_reviews_company_employee_period on public.erp_hr_performance_reviews(company_id,employee_id,period_start desc);

commit;
