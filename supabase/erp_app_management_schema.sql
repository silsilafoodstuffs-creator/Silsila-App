-- Silsila ERP: managed applications, themes, assets, permissions and activity history.
-- Apply after the base ERP schema. Review referenced table names and tenant model
-- against the deployed database before applying this migration.
-- RLS is enabled without permissive policies intentionally; production policies
-- must be tenant-scoped and enforced by trusted server-side authorization.

create table if not exists public.erp_managed_apps (
  id uuid primary key default gen_random_uuid(),
  company_id uuid not null references public.erp_companies(id) on delete restrict,
  app_key text not null,
  display_name text not null,
  description text,
  status text not null default 'in_development'
    check (status in ('active','in_development','paused')),
  package_name text,
  web_url text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique(company_id, app_key)
);

create table if not exists public.erp_app_theme_settings (
  id uuid primary key default gen_random_uuid(),
  app_id uuid not null references public.erp_managed_apps(id) on delete cascade,
  display_name text not null,
  primary_color text not null default '#3E007D'
    check (primary_color ~ '^#[0-9A-Fa-f]{6}([0-9A-Fa-f]{2})?$'),
  accent_color text not null default '#FFA015'
    check (accent_color ~ '^#[0-9A-Fa-f]{6}([0-9A-Fa-f]{2})?$'),
  logo_path text,
  splash_image_path text,
  icon_path text,
  updated_by uuid references auth.users(id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique(app_id)
);

create table if not exists public.erp_app_assets (
  id uuid primary key default gen_random_uuid(),
  app_id uuid not null references public.erp_managed_apps(id) on delete cascade,
  asset_type text not null check (asset_type in (
    'app_logo','splash','app_icon','category','item','supplier',
    'customer','shipping_company','banner_ad','other'
  )),
  storage_path text not null,
  display_name text not null,
  entity_id uuid,
  mime_type text,
  file_size_bytes bigint check (file_size_bytes is null or file_size_bytes >= 0),
  alt_text text,
  uploaded_by uuid references auth.users(id) on delete set null,
  created_at timestamptz not null default now()
);

create index if not exists erp_app_assets_app_type_idx
  on public.erp_app_assets(app_id, asset_type, created_at desc);
create index if not exists erp_app_assets_entity_idx
  on public.erp_app_assets(asset_type, entity_id);

create table if not exists public.erp_app_role_permissions (
  id uuid primary key default gen_random_uuid(),
  app_id uuid not null references public.erp_managed_apps(id) on delete cascade,
  role_key text not null,
  permission_key text not null,
  allowed boolean not null default false,
  updated_by uuid references auth.users(id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique(app_id, role_key, permission_key)
);

create table if not exists public.erp_app_activity_log (
  id bigint generated always as identity primary key,
  company_id uuid not null references public.erp_companies(id) on delete restrict,
  app_id uuid references public.erp_managed_apps(id) on delete set null,
  actor_id uuid references auth.users(id) on delete set null,
  action text not null,
  entity_type text not null,
  entity_id text not null,
  details jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now()
);

create index if not exists erp_app_activity_company_time_idx
  on public.erp_app_activity_log(company_id, created_at desc);
create index if not exists erp_app_activity_app_time_idx
  on public.erp_app_activity_log(app_id, created_at desc);

drop trigger if exists erp_managed_apps_updated_at on public.erp_managed_apps;
create trigger erp_managed_apps_updated_at before update on public.erp_managed_apps
for each row execute function public.erp_set_updated_at();

drop trigger if exists erp_app_theme_settings_updated_at on public.erp_app_theme_settings;
create trigger erp_app_theme_settings_updated_at before update on public.erp_app_theme_settings
for each row execute function public.erp_set_updated_at();

drop trigger if exists erp_app_role_permissions_updated_at on public.erp_app_role_permissions;
create trigger erp_app_role_permissions_updated_at before update on public.erp_app_role_permissions
for each row execute function public.erp_set_updated_at();

alter table public.erp_managed_apps enable row level security;
alter table public.erp_app_theme_settings enable row level security;
alter table public.erp_app_assets enable row level security;
alter table public.erp_app_role_permissions enable row level security;
alter table public.erp_app_activity_log enable row level security;

-- Company-scoped policies. Requires erp_security_membership.sql to be applied first.
-- Registry writes and identity changes are limited to company owners/admins.
drop policy if exists erp_managed_apps_select_member on public.erp_managed_apps;
create policy erp_managed_apps_select_member on public.erp_managed_apps
for select to authenticated
using (public.erp_user_can_access_company(company_id));

drop policy if exists erp_managed_apps_insert_admin on public.erp_managed_apps;
create policy erp_managed_apps_insert_admin on public.erp_managed_apps
for insert to authenticated
with check (public.erp_user_has_company_role(company_id, array['owner','admin']::text[]));

drop policy if exists erp_managed_apps_update_admin on public.erp_managed_apps;
create policy erp_managed_apps_update_admin on public.erp_managed_apps
for update to authenticated
using (public.erp_user_has_company_role(company_id, array['owner','admin']::text[]))
with check (public.erp_user_has_company_role(company_id, array['owner','admin']::text[]));

drop policy if exists erp_app_theme_select_member on public.erp_app_theme_settings;
create policy erp_app_theme_select_member on public.erp_app_theme_settings
for select to authenticated
using (exists (
  select 1 from public.erp_managed_apps a
  where a.id = app_id and public.erp_user_can_access_company(a.company_id)
));

drop policy if exists erp_app_theme_insert_admin on public.erp_app_theme_settings;
create policy erp_app_theme_insert_admin on public.erp_app_theme_settings
for insert to authenticated
with check (exists (
  select 1 from public.erp_managed_apps a
  where a.id = app_id and public.erp_user_has_company_role(a.company_id, array['owner','admin']::text[])
));

drop policy if exists erp_app_theme_update_admin on public.erp_app_theme_settings;
create policy erp_app_theme_update_admin on public.erp_app_theme_settings
for update to authenticated
using (exists (
  select 1 from public.erp_managed_apps a
  where a.id = app_id and public.erp_user_has_company_role(a.company_id, array['owner','admin']::text[])
))
with check (exists (
  select 1 from public.erp_managed_apps a
  where a.id = app_id and public.erp_user_has_company_role(a.company_id, array['owner','admin']::text[])
));

drop policy if exists erp_app_assets_select_member on public.erp_app_assets;
create policy erp_app_assets_select_member on public.erp_app_assets
for select to authenticated
using (exists (
  select 1 from public.erp_managed_apps a
  where a.id = app_id and public.erp_user_can_access_company(a.company_id)
));

drop policy if exists erp_app_assets_insert_admin on public.erp_app_assets;
create policy erp_app_assets_insert_admin on public.erp_app_assets
for insert to authenticated
with check (
  (uploaded_by is null or uploaded_by = auth.uid())
  and exists (
    select 1 from public.erp_managed_apps a
    where a.id = app_id and public.erp_user_has_company_role(a.company_id, array['owner','admin']::text[])
  )
);

drop policy if exists erp_app_assets_delete_admin on public.erp_app_assets;
create policy erp_app_assets_delete_admin on public.erp_app_assets
for delete to authenticated
using (exists (
  select 1 from public.erp_managed_apps a
  where a.id = app_id and public.erp_user_has_company_role(a.company_id, array['owner','admin']::text[])
));

drop policy if exists erp_app_permissions_select_member on public.erp_app_role_permissions;
create policy erp_app_permissions_select_member on public.erp_app_role_permissions
for select to authenticated
using (exists (
  select 1 from public.erp_managed_apps a
  where a.id = app_id and public.erp_user_can_access_company(a.company_id)
));

drop policy if exists erp_app_permissions_insert_admin on public.erp_app_role_permissions;
create policy erp_app_permissions_insert_admin on public.erp_app_role_permissions
for insert to authenticated
with check (
  (updated_by is null or updated_by = auth.uid())
  and exists (
    select 1 from public.erp_managed_apps a
    where a.id = app_id and public.erp_user_has_company_role(a.company_id, array['owner','admin']::text[])
  )
);

drop policy if exists erp_app_permissions_update_admin on public.erp_app_role_permissions;
create policy erp_app_permissions_update_admin on public.erp_app_role_permissions
for update to authenticated
using (exists (
  select 1 from public.erp_managed_apps a
  where a.id = app_id and public.erp_user_has_company_role(a.company_id, array['owner','admin']::text[])
))
with check (
  (updated_by is null or updated_by = auth.uid())
  and exists (
    select 1 from public.erp_managed_apps a
    where a.id = app_id and public.erp_user_has_company_role(a.company_id, array['owner','admin']::text[])
  )
);

drop policy if exists erp_app_permissions_delete_admin on public.erp_app_role_permissions;
create policy erp_app_permissions_delete_admin on public.erp_app_role_permissions
for delete to authenticated
using (exists (
  select 1 from public.erp_managed_apps a
  where a.id = app_id and public.erp_user_has_company_role(a.company_id, array['owner','admin']::text[])
));

-- Activity history is readable by company members. Client-side inserts/updates/deletes
-- intentionally remain blocked; a trusted backend should append audit events.
drop policy if exists erp_app_activity_select_member on public.erp_app_activity_log;
create policy erp_app_activity_select_member on public.erp_app_activity_log
for select to authenticated
using (public.erp_user_can_access_company(company_id));

grant select, insert, update on public.erp_managed_apps to authenticated;
grant select, insert, update on public.erp_app_theme_settings to authenticated;
grant select, insert, delete on public.erp_app_assets to authenticated;
grant select, insert, update, delete on public.erp_app_role_permissions to authenticated;
grant select on public.erp_app_activity_log to authenticated;

-- Deployment checklist:
-- 1. Confirm erp_companies and erp_set_updated_at() exist.
-- 2. Add restrictive company-scoped RLS policies for each table.
-- 3. Configure private Storage buckets and path policies; store paths, not public secrets.
-- 4. Enforce role permissions in trusted backend/RPCs; UI toggles are not authorization.
-- 5. Restrict activity-log inserts to trusted server functions and prevent client edits.
-- 6. Seed app_key values: silsila, app_2, app_3 only after confirming ownership/company.
-- 7. Review entity_id relations with actual item, category, party and shipping-company tables.
