create table if not exists public.erp_user_quick_access (
  company_id uuid not null references public.erp_companies(id) on delete cascade,
  user_id uuid not null references auth.users(id) on delete cascade,
  menu_key text not null,
  menu_name text not null,
  submenu_name text not null default '',
  page_name text not null,
  created_at timestamptz not null default now(),
  primary key (company_id, user_id, menu_key),
  check (length(menu_key) between 1 and 500),
  check (menu_key = menu_name || '::' || submenu_name || '::' || page_name)
);

alter table public.erp_user_quick_access enable row level security;

drop policy if exists erp_user_quick_access_select_own on public.erp_user_quick_access;
create policy erp_user_quick_access_select_own on public.erp_user_quick_access
for select to authenticated using (
  user_id = (select auth.uid()) and exists (
    select 1 from public.erp_company_members m
    where m.company_id = erp_user_quick_access.company_id
      and m.user_id = (select auth.uid()) and m.is_active = true
  )
);

drop policy if exists erp_user_quick_access_insert_own on public.erp_user_quick_access;
create policy erp_user_quick_access_insert_own on public.erp_user_quick_access
for insert to authenticated with check (
  user_id = (select auth.uid()) and exists (
    select 1 from public.erp_company_members m
    where m.company_id = erp_user_quick_access.company_id
      and m.user_id = (select auth.uid()) and m.is_active = true
  )
);

drop policy if exists erp_user_quick_access_update_own on public.erp_user_quick_access;
create policy erp_user_quick_access_update_own on public.erp_user_quick_access
for update to authenticated using (
  user_id = (select auth.uid()) and exists (
    select 1 from public.erp_company_members m
    where m.company_id = erp_user_quick_access.company_id
      and m.user_id = (select auth.uid()) and m.is_active = true
  )
) with check (
  user_id = (select auth.uid()) and exists (
    select 1 from public.erp_company_members m
    where m.company_id = erp_user_quick_access.company_id
      and m.user_id = (select auth.uid()) and m.is_active = true
  )
);

drop policy if exists erp_user_quick_access_delete_own on public.erp_user_quick_access;
create policy erp_user_quick_access_delete_own on public.erp_user_quick_access
for delete to authenticated using (
  user_id = (select auth.uid()) and exists (
    select 1 from public.erp_company_members m
    where m.company_id = erp_user_quick_access.company_id
      and m.user_id = (select auth.uid()) and m.is_active = true
  )
);

grant select, insert, update, delete on public.erp_user_quick_access to authenticated;

insert into public.erp_user_quick_access
  (company_id, user_id, menu_key, menu_name, submenu_name, page_name)
select distinct
  m.company_id,
  u.auth_user_id,
  m.menu_name || '::' || m.submenu_name || '::' || m.page_name,
  m.menu_name,
  m.submenu_name,
  m.page_name
from public.erp_user_permission_matrix m
join public.erp_users u
  on u.id = m.user_id and u.company_id = m.company_id
where m.can_access = true
  and m.show_in_quick_tasks = true
  and u.auth_user_id is not null
on conflict (company_id, user_id, menu_key) do nothing;
