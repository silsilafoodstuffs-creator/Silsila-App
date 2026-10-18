-- Company-scoped storage for ERP workspace configuration drafts.
-- Values are persisted as JSONB; transaction enforcement must also be added to
-- the corresponding server-side posting procedures before treating a rule as active.
begin;

create table if not exists public.erp_company_settings (
  id uuid primary key default gen_random_uuid(),
  company_id uuid not null references public.erp_companies(id) on delete cascade,
  setting_key text not null check (length(trim(setting_key)) between 1 and 120),
  setting_value jsonb not null default '{}'::jsonb,
  updated_by uuid references auth.users(id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique(company_id, setting_key)
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

drop policy if exists erp_company_settings_insert_admin on public.erp_company_settings;
create policy erp_company_settings_insert_admin on public.erp_company_settings
for insert to authenticated
with check (
  (updated_by is null or updated_by = auth.uid())
  and public.erp_user_has_company_role(company_id, array['owner','admin']::text[])
);

drop policy if exists erp_company_settings_update_admin on public.erp_company_settings;
create policy erp_company_settings_update_admin on public.erp_company_settings
for update to authenticated
using (public.erp_user_has_company_role(company_id, array['owner','admin']::text[]))
with check (
  (updated_by is null or updated_by = auth.uid())
  and public.erp_user_has_company_role(company_id, array['owner','admin']::text[])
);

grant select, insert, update on public.erp_company_settings to authenticated;
commit;
