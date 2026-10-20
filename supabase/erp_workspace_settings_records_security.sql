-- Silsila ERP: company settings and generic workspace records.
-- Apply after erp_schema.sql and the ERP company membership/RLS setup.
-- Additive migration: creates missing tables and company-scoped policies only.
begin;

create table if not exists public.erp_company_settings (
  id uuid primary key default gen_random_uuid(),
  company_id uuid not null references public.erp_companies(id) on delete cascade,
  setting_key text not null check (length(trim(setting_key)) between 1 and 120),
  setting_value jsonb not null default '{}'::jsonb check (jsonb_typeof(setting_value) = 'object'),
  updated_by uuid references auth.users(id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (company_id, setting_key)
);

create index if not exists erp_company_settings_company_idx
  on public.erp_company_settings(company_id, setting_key);

drop trigger if exists erp_company_settings_updated_at on public.erp_company_settings;
create trigger erp_company_settings_updated_at
before update on public.erp_company_settings
for each row execute function public.erp_set_updated_at();

alter table public.erp_company_settings enable row level security;
drop policy if exists erp_company_settings_select_member on public.erp_company_settings;
create policy erp_company_settings_select_member on public.erp_company_settings
for select to authenticated
using (public.erp_user_can_access_company(company_id));

drop policy if exists erp_company_settings_insert_operator on public.erp_company_settings;
create policy erp_company_settings_insert_operator on public.erp_company_settings
for insert to authenticated
with check (
  public.erp_user_has_company_role(company_id, array['owner','admin','accountant','manager','operator']::text[])
  and (updated_by is null or updated_by = (select auth.uid()))
);

drop policy if exists erp_company_settings_update_operator on public.erp_company_settings;
create policy erp_company_settings_update_operator on public.erp_company_settings
for update to authenticated
using (public.erp_user_has_company_role(company_id, array['owner','admin','accountant','manager','operator']::text[]))
with check (
  public.erp_user_has_company_role(company_id, array['owner','admin','accountant','manager','operator']::text[])
  and (updated_by is null or updated_by = (select auth.uid()))
);

drop policy if exists erp_company_settings_delete_admin on public.erp_company_settings;
create policy erp_company_settings_delete_admin on public.erp_company_settings
for delete to authenticated
using (public.erp_user_has_company_role(company_id, array['owner','admin']::text[]));

revoke all on public.erp_company_settings from anon;
grant select, insert, update, delete on public.erp_company_settings to authenticated;

create table if not exists public.erp_workspace_records (
  id uuid primary key default gen_random_uuid(),
  company_id uuid not null references public.erp_companies(id) on delete restrict,
  page_key text not null check (length(trim(page_key)) between 1 and 120),
  record_key text not null check (length(trim(record_key)) between 1 and 180),
  record_data jsonb not null default '{}'::jsonb check (jsonb_typeof(record_data) = 'object'),
  created_by uuid references auth.users(id) on delete set null,
  updated_by uuid references auth.users(id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique(company_id, page_key, record_key)
);

create index if not exists erp_workspace_records_page_idx
  on public.erp_workspace_records(company_id, page_key, created_at desc);

drop trigger if exists erp_workspace_records_updated_at on public.erp_workspace_records;
create trigger erp_workspace_records_updated_at
before update on public.erp_workspace_records
for each row execute function public.erp_set_updated_at();

alter table public.erp_workspace_records enable row level security;
drop policy if exists erp_workspace_records_select_member on public.erp_workspace_records;
create policy erp_workspace_records_select_member on public.erp_workspace_records
for select to authenticated
using (public.erp_user_can_access_company(company_id));

drop policy if exists erp_workspace_records_insert_operator on public.erp_workspace_records;
create policy erp_workspace_records_insert_operator on public.erp_workspace_records
for insert to authenticated
with check (
  public.erp_user_has_company_role(company_id, array['owner','admin','accountant','manager','operator']::text[])
  and (created_by is null or created_by = (select auth.uid()))
  and (updated_by is null or updated_by = (select auth.uid()))
);

drop policy if exists erp_workspace_records_update_operator on public.erp_workspace_records;
create policy erp_workspace_records_update_operator on public.erp_workspace_records
for update to authenticated
using (public.erp_user_has_company_role(company_id, array['owner','admin','accountant','manager','operator']::text[]))
with check (
  public.erp_user_has_company_role(company_id, array['owner','admin','accountant','manager','operator']::text[])
  and (updated_by is null or updated_by = (select auth.uid()))
);

drop policy if exists erp_workspace_records_delete_admin on public.erp_workspace_records;
create policy erp_workspace_records_delete_admin on public.erp_workspace_records
for delete to authenticated
using (public.erp_user_has_company_role(company_id, array['owner','admin']::text[]));

revoke all on public.erp_workspace_records from anon;
grant select, insert, update, delete on public.erp_workspace_records to authenticated;

commit;
