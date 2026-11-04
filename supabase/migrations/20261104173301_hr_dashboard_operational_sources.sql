create table if not exists public.erp_hr_employee_compliance (
  id uuid primary key default gen_random_uuid(),
  company_id uuid not null references public.erp_companies(id) on delete cascade,
  employee_id uuid not null references public.erp_employees(id) on delete cascade,
  record_type text not null check (record_type in ('health_insurance','social_insurance','license')),
  status text not null default 'in_progress' check (status in ('insured','uninsured','in_progress','valid','expired','not_required')),
  provider text, reference_number text, issued_on date, expires_on date, notes text,
  created_by uuid, created_at timestamptz not null default now(), updated_at timestamptz not null default now(),
  check (expires_on is null or issued_on is null or expires_on >= issued_on)
);
create index if not exists idx_hr_compliance_company_type_status on public.erp_hr_employee_compliance(company_id,record_type,status);
create index if not exists idx_hr_compliance_employee on public.erp_hr_employee_compliance(employee_id);
create index if not exists idx_hr_compliance_expiry on public.erp_hr_employee_compliance(company_id,expires_on);
create table if not exists public.erp_hr_training_records (
  id uuid primary key default gen_random_uuid(),
  company_id uuid not null references public.erp_companies(id) on delete cascade,
  employee_id uuid not null references public.erp_employees(id) on delete cascade,
  course_name text not null, provider text,
  status text not null default 'planned' check (status in ('planned','in_progress','completed','expired','cancelled')),
  starts_on date, ends_on date, certificate_expires_on date, notes text, created_by uuid,
  created_at timestamptz not null default now(), updated_at timestamptz not null default now(),
  check (ends_on is null or starts_on is null or ends_on >= starts_on)
);
create index if not exists idx_hr_training_company_status on public.erp_hr_training_records(company_id,status);
create index if not exists idx_hr_training_employee on public.erp_hr_training_records(employee_id);
create index if not exists idx_hr_training_expiry on public.erp_hr_training_records(company_id,certificate_expires_on);
create table if not exists public.erp_hr_recruitment_candidates (
  id uuid primary key default gen_random_uuid(),
  company_id uuid not null references public.erp_companies(id) on delete cascade,
  job_id uuid references public.erp_hr_jobs(id) on delete set null,
  candidate_name text not null, phone text, email text,
  status text not null default 'new' check (status in ('new','screening','interview','accepted','rejected','withdrawn')),
  applied_on date not null default current_date, decision_on date, source text, notes text, created_by uuid,
  created_at timestamptz not null default now(), updated_at timestamptz not null default now(),
  check (decision_on is null or decision_on >= applied_on)
);
create index if not exists idx_hr_candidates_company_status on public.erp_hr_recruitment_candidates(company_id,status,applied_on);
create index if not exists idx_hr_candidates_job on public.erp_hr_recruitment_candidates(job_id);
create table if not exists public.erp_hr_employee_movements (
  id uuid primary key default gen_random_uuid(),
  company_id uuid not null references public.erp_companies(id) on delete cascade,
  employee_id uuid not null references public.erp_employees(id) on delete cascade,
  movement_type text not null check (movement_type in ('hire','resignation','termination','retirement','transfer','suspension','return_to_work')),
  effective_on date not null default current_date, reason text, rehire_eligible boolean, notes text, created_by uuid,
  created_at timestamptz not null default now()
);
create index if not exists idx_hr_movements_company_type_date on public.erp_hr_employee_movements(company_id,movement_type,effective_on);
create index if not exists idx_hr_movements_employee on public.erp_hr_employee_movements(employee_id);
create or replace function public.erp_hr_apply_employee_movement()
returns trigger language plpgsql security definer set search_path=public as $$
begin
  if new.movement_type in ('resignation','termination','retirement') then
    update public.erp_employees set is_active=false, employment_status='منتهي الخدمة', updated_at=now()
     where id=new.employee_id and company_id=new.company_id;
  elsif new.movement_type='return_to_work' then
    update public.erp_employees set is_active=true, employment_status='نشط', updated_at=now()
     where id=new.employee_id and company_id=new.company_id;
  end if;
  return new;
end; $$;
drop trigger if exists trg_erp_hr_apply_employee_movement on public.erp_hr_employee_movements;
create trigger trg_erp_hr_apply_employee_movement after insert on public.erp_hr_employee_movements
for each row execute function public.erp_hr_apply_employee_movement();
do $$
declare t text;
begin
 foreach t in array array['erp_hr_employee_compliance','erp_hr_training_records','erp_hr_recruitment_candidates','erp_hr_employee_movements'] loop
  execute format('alter table public.%I enable row level security',t);
  execute format('drop policy if exists %I on public.%I',t||'_select_company',t);
  execute format('create policy %I on public.%I for select using (public.erp_user_can_access_company(company_id))',t||'_select_company',t);
  execute format('drop policy if exists %I on public.%I',t||'_insert_hr',t);
  execute format('create policy %I on public.%I for insert with check (public.erp_user_has_company_role(company_id, array[''owner'',''admin'',''manager'']))',t||'_insert_hr',t);
  execute format('drop policy if exists %I on public.%I',t||'_update_hr',t);
  execute format('create policy %I on public.%I for update using (public.erp_user_has_company_role(company_id, array[''owner'',''admin'',''manager''])) with check (public.erp_user_has_company_role(company_id, array[''owner'',''admin'',''manager'']))',t||'_update_hr',t);
  execute format('drop policy if exists %I on public.%I',t||'_delete_hr',t);
  execute format('create policy %I on public.%I for delete using (public.erp_user_has_company_role(company_id, array[''owner'',''admin'',''manager'']))',t||'_delete_hr',t);
 end loop;
end $$;