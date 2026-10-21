-- Company-scoped assignment of active inventory items to active sales employees.
begin;

create table if not exists public.erp_delegate_item_assignments (
  id uuid primary key default gen_random_uuid(),
  company_id uuid not null references public.erp_companies(id) on delete cascade,
  employee_id uuid not null references public.erp_employees(id) on delete cascade,
  item_id uuid not null references public.erp_items(id) on delete cascade,
  is_active boolean not null default true,
  assigned_by uuid references auth.users(id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique(company_id, employee_id, item_id)
);

create index if not exists erp_delegate_item_assignments_employee_idx
  on public.erp_delegate_item_assignments(company_id, employee_id, is_active);
create index if not exists erp_delegate_item_assignments_item_idx
  on public.erp_delegate_item_assignments(company_id, item_id, is_active);

create or replace function public.erp_validate_delegate_item_assignment()
returns trigger
language plpgsql
set search_path = public
as $$
begin
  if not exists (
    select 1 from public.erp_employees e
    where e.id = new.employee_id and e.company_id = new.company_id
      and (
        new.is_active = false
        or (
          e.is_active = true
          and (coalesce(e.job_title, '') ilike '%مندوب%'
            or coalesce(e.job_title, '') ilike '%مبيعات%'
            or coalesce(e.job_title, '') ilike '%sales%')
        )
      )
  ) then
    raise exception 'يجب اختيار موظف مبيعات/مندوب نشط تابع للشركة نفسها عند تفعيل التوزيع.';
  end if;

  if not exists (
    select 1 from public.erp_items i
    where i.id = new.item_id and i.company_id = new.company_id
      and (new.is_active = false or i.is_active = true)
  ) then
    raise exception 'يجب اختيار صنف نشط تابع للشركة نفسها عند تفعيل التوزيع.';
  end if;
  return new;
end;
$$;

drop trigger if exists erp_validate_delegate_item_assignment_trigger
  on public.erp_delegate_item_assignments;
create trigger erp_validate_delegate_item_assignment_trigger
before insert or update on public.erp_delegate_item_assignments
for each row execute function public.erp_validate_delegate_item_assignment();

drop trigger if exists erp_delegate_item_assignments_updated_at
  on public.erp_delegate_item_assignments;
create trigger erp_delegate_item_assignments_updated_at
before update on public.erp_delegate_item_assignments
for each row execute function public.erp_set_updated_at();

alter table public.erp_delegate_item_assignments enable row level security;

drop policy if exists erp_delegate_item_assignments_select_member
  on public.erp_delegate_item_assignments;
create policy erp_delegate_item_assignments_select_member
on public.erp_delegate_item_assignments for select to authenticated
using (public.erp_user_can_access_company(company_id));

drop policy if exists erp_delegate_item_assignments_insert_manager
  on public.erp_delegate_item_assignments;
create policy erp_delegate_item_assignments_insert_manager
on public.erp_delegate_item_assignments for insert to authenticated
with check (
  (assigned_by is null or assigned_by = (select auth.uid()))
  and public.erp_user_has_company_role(company_id, array['owner','admin','manager']::text[])
);

drop policy if exists erp_delegate_item_assignments_update_manager
  on public.erp_delegate_item_assignments;
create policy erp_delegate_item_assignments_update_manager
on public.erp_delegate_item_assignments for update to authenticated
using (public.erp_user_has_company_role(company_id, array['owner','admin','manager']::text[]))
with check (
  (assigned_by is null or assigned_by = (select auth.uid()))
  and public.erp_user_has_company_role(company_id, array['owner','admin','manager']::text[])
);

drop policy if exists erp_delegate_item_assignments_delete_manager
  on public.erp_delegate_item_assignments;
create policy erp_delegate_item_assignments_delete_manager
on public.erp_delegate_item_assignments for delete to authenticated
using (public.erp_user_has_company_role(company_id, array['owner','admin','manager']::text[]));

grant select, insert, update, delete on public.erp_delegate_item_assignments to authenticated;
commit;
