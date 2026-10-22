-- Company-scoped cost centers for branch and financial analysis.
begin;

create table if not exists public.erp_cost_centers (
  id uuid primary key default gen_random_uuid(),
  company_id uuid not null references public.erp_companies(id) on delete cascade,
  branch_id uuid references public.erp_branches(id) on delete restrict,
  parent_id uuid references public.erp_cost_centers(id) on delete restrict,
  center_code text not null,
  center_name text not null,
  center_name_ar text not null default '',
  center_name_en text null,
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique(company_id, center_code),
  check (length(trim(center_code)) > 0),
  check (length(trim(center_name)) > 0),
  check (parent_id is null or parent_id <> id)
);

alter table public.erp_cost_centers add column if not exists center_name_ar text;
alter table public.erp_cost_centers add column if not exists center_name_en text;
update public.erp_cost_centers set center_name_ar = center_name where center_name_ar is null or btrim(center_name_ar) = '';
alter table public.erp_cost_centers alter column center_name_ar set default '';
alter table public.erp_cost_centers alter column center_name_ar set not null;

create index if not exists erp_cost_centers_company_idx
  on public.erp_cost_centers(company_id, center_code);

create or replace function public.erp_validate_cost_center()
returns trigger
language plpgsql
set search_path = public
as $$
begin
  if new.branch_id is not null and not exists (
    select 1 from public.erp_branches b
    where b.id = new.branch_id and b.company_id = new.company_id
  ) then
    raise exception 'يجب اختيار فرع تابع للشركة نفسها.';
  end if;

  if new.parent_id is not null and not exists (
    select 1 from public.erp_cost_centers p
    where p.id = new.parent_id and p.company_id = new.company_id
  ) then
    raise exception 'يجب اختيار مركز تكلفة أب تابع للشركة نفسها.';
  end if;

  if new.parent_id = new.id then
    raise exception 'لا يمكن جعل مركز التكلفة أبًا لنفسه.';
  end if;

  if new.parent_id is not null and exists (
    with recursive descendants(id) as (
      select new.id
      union
      select child.id
      from public.erp_cost_centers child
      join descendants d on child.parent_id = d.id
      where child.id <> new.id
    )
    select 1 from descendants where id = new.parent_id
  ) then
    raise exception 'لا يمكن إنشاء حلقة في التسلسل الهرمي لمراكز التكلفة.';
  end if;

  return new;
end;
$$;

drop trigger if exists erp_validate_cost_center_trigger on public.erp_cost_centers;
create trigger erp_validate_cost_center_trigger
before insert or update on public.erp_cost_centers
for each row execute function public.erp_validate_cost_center();

drop trigger if exists erp_cost_centers_updated_at on public.erp_cost_centers;
create trigger erp_cost_centers_updated_at
before update on public.erp_cost_centers
for each row execute function public.erp_set_updated_at();

alter table public.erp_cost_centers enable row level security;

drop policy if exists erp_cost_centers_select_member on public.erp_cost_centers;
create policy erp_cost_centers_select_member on public.erp_cost_centers
for select to authenticated
using (public.erp_user_can_access_company(company_id));

drop policy if exists erp_cost_centers_insert_manager on public.erp_cost_centers;
create policy erp_cost_centers_insert_manager on public.erp_cost_centers
for insert to authenticated
with check (public.erp_user_has_company_role(company_id, array['owner','admin','manager','accountant']::text[]));

drop policy if exists erp_cost_centers_update_manager on public.erp_cost_centers;
create policy erp_cost_centers_update_manager on public.erp_cost_centers
for update to authenticated
using (public.erp_user_has_company_role(company_id, array['owner','admin','manager','accountant']::text[]))
with check (public.erp_user_has_company_role(company_id, array['owner','admin','manager','accountant']::text[]));

drop policy if exists erp_cost_centers_delete_manager on public.erp_cost_centers;
create policy erp_cost_centers_delete_manager on public.erp_cost_centers
for delete to authenticated
using (public.erp_user_has_company_role(company_id, array['owner','admin','manager','accountant']::text[]));

grant select, insert, update, delete on public.erp_cost_centers to authenticated;
commit;
