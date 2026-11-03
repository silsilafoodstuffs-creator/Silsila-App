create unique index if not exists erp_business_workspace_employees_workspace_id_id_uidx
 on public.erp_business_workspace_employees(workspace_id,id);
create table if not exists public.erp_business_workspace_employee_leaves(
 id uuid primary key default gen_random_uuid(),
 workspace_id uuid not null references public.erp_business_workspaces(id) on delete cascade,
 employee_id uuid not null,
 leave_type text not null default 'annual' check(leave_type in ('annual','sick','unpaid','emergency','other')),
 start_date date not null,end_date date not null,
 status text not null default 'pending' check(status in ('pending','approved','rejected','cancelled')),
 notes text,created_by uuid not null references auth.users(id),
 reviewed_by uuid references auth.users(id),reviewed_at timestamptz,
 created_at timestamptz not null default now(),updated_at timestamptz not null default now(),
 constraint erp_business_workspace_employee_leaves_date_check check(end_date>=start_date),
 constraint erp_business_workspace_employee_leaves_employee_fk
  foreign key(workspace_id,employee_id) references public.erp_business_workspace_employees(workspace_id,id) on delete cascade
);
create index if not exists erp_business_workspace_employee_leaves_date_idx
 on public.erp_business_workspace_employee_leaves(workspace_id,start_date desc,status);
alter table public.erp_business_workspace_employee_leaves enable row level security;
grant select,insert,update,delete on public.erp_business_workspace_employee_leaves to authenticated;
drop policy if exists workspace_employee_leave_select on public.erp_business_workspace_employee_leaves;
create policy workspace_employee_leave_select on public.erp_business_workspace_employee_leaves for select to authenticated
 using(private.can_access_business_workspace(workspace_id,'hr.read'));
drop policy if exists workspace_employee_leave_insert on public.erp_business_workspace_employee_leaves;
create policy workspace_employee_leave_insert on public.erp_business_workspace_employee_leaves for insert to authenticated
 with check(private.can_access_business_workspace(workspace_id,'hr.manage') and created_by=(select auth.uid()));
drop policy if exists workspace_employee_leave_update on public.erp_business_workspace_employee_leaves;
create policy workspace_employee_leave_update on public.erp_business_workspace_employee_leaves for update to authenticated
 using(private.can_access_business_workspace(workspace_id,'hr.manage'))
 with check(private.can_access_business_workspace(workspace_id,'hr.manage'));
drop policy if exists workspace_employee_leave_delete on public.erp_business_workspace_employee_leaves;
create policy workspace_employee_leave_delete on public.erp_business_workspace_employee_leaves for delete to authenticated
 using(private.can_access_business_workspace(workspace_id,'hr.manage') and status in ('pending','rejected','cancelled'));
