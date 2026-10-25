create table if not exists public.erp_user_permissions (
 id uuid primary key default gen_random_uuid(),
 company_id uuid not null references public.erp_companies(id) on delete cascade,
 user_id uuid not null references auth.users(id) on delete cascade,
 menu_key text not null,
 allow_access boolean not null default false,
 can_add boolean not null default false,
 can_edit boolean not null default false,
 can_delete boolean not null default false,
 can_save boolean not null default false,
 can_print boolean not null default false,
 can_export_excel boolean not null default false,
 can_export_pdf boolean not null default false,
 show_in_quick_tasks boolean not null default false,
 updated_at timestamptz not null default now(),
 updated_by uuid references auth.users(id),
 unique(company_id,user_id,menu_key),
 check(length(menu_key) between 1 and 500)
);
create index if not exists erp_user_permissions_company_user_idx on public.erp_user_permissions(company_id,user_id);
alter table public.erp_user_permissions enable row level security;
drop policy if exists erp_user_permissions_member_select on public.erp_user_permissions;
create policy erp_user_permissions_member_select on public.erp_user_permissions for select to authenticated using (
 exists(select 1 from public.erp_company_members m where m.company_id=erp_user_permissions.company_id and m.user_id=auth.uid() and m.is_active=true and m.member_role in ('owner','admin')));
drop policy if exists erp_user_permissions_member_insert on public.erp_user_permissions;
create policy erp_user_permissions_member_insert on public.erp_user_permissions for insert to authenticated with check (
 exists(select 1 from public.erp_company_members m where m.company_id=erp_user_permissions.company_id and m.user_id=auth.uid() and m.is_active=true and m.member_role in ('owner','admin')));
drop policy if exists erp_user_permissions_member_update on public.erp_user_permissions;
create policy erp_user_permissions_member_update on public.erp_user_permissions for update to authenticated using (
 exists(select 1 from public.erp_company_members m where m.company_id=erp_user_permissions.company_id and m.user_id=auth.uid() and m.is_active=true and m.member_role in ('owner','admin')))
 with check (exists(select 1 from public.erp_company_members m where m.company_id=erp_user_permissions.company_id and m.user_id=auth.uid() and m.is_active=true and m.member_role in ('owner','admin')));
grant select,insert,update on public.erp_user_permissions to authenticated;
