-- Silsila ERP: storage for Egyptian Tax Authority e-invoice settings and operation queue.
-- Apply this script in the Supabase SQL Editor. This does not itself connect to ETA APIs.
create table if not exists public.erp_einvoice_settings (
  id uuid primary key default gen_random_uuid(),
  company_id uuid not null unique references public.erp_companies(id) on delete cascade,
  taxpayer_number text not null,
  branch_code text not null default '0',
  activity_code text,
  client_id text,
  environment text not null default 'preproduction' check (environment in ('preproduction','production')),
  connection_status text not null default 'not_tested',
  updated_by uuid,
  updated_at timestamptz not null default now()
);

create table if not exists public.erp_einvoice_operations (
  id uuid primary key default gen_random_uuid(),
  company_id uuid not null references public.erp_companies(id) on delete cascade,
  action_key text not null,
  document_type text,
  reference_query text,
  status text not null default 'pending_setup',
  details jsonb not null default '{}'::jsonb,
  response_data jsonb,
  created_by uuid,
  created_at timestamptz not null default now(),
  processed_at timestamptz
);

create index if not exists erp_einvoice_operations_company_created_idx
  on public.erp_einvoice_operations (company_id, created_at desc);
create index if not exists erp_einvoice_operations_status_idx
  on public.erp_einvoice_operations (status);

alter table public.erp_einvoice_settings enable row level security;
alter table public.erp_einvoice_operations enable row level security;

drop policy if exists erp_einvoice_settings_member_access on public.erp_einvoice_settings;
create policy erp_einvoice_settings_member_access
on public.erp_einvoice_settings for all to authenticated
using (exists (
  select 1 from public.erp_company_members m
  where m.company_id = erp_einvoice_settings.company_id
    and m.user_id = auth.uid()
    and coalesce(m.is_active, true) = true
))
with check (exists (
  select 1 from public.erp_company_members m
  where m.company_id = erp_einvoice_settings.company_id
    and m.user_id = auth.uid()
    and coalesce(m.is_active, true) = true
));

drop policy if exists erp_einvoice_operations_member_access on public.erp_einvoice_operations;
create policy erp_einvoice_operations_member_access
on public.erp_einvoice_operations for all to authenticated
using (exists (
  select 1 from public.erp_company_members m
  where m.company_id = erp_einvoice_operations.company_id
    and m.user_id = auth.uid()
    and coalesce(m.is_active, true) = true
))
with check (exists (
  select 1 from public.erp_company_members m
  where m.company_id = erp_einvoice_operations.company_id
    and m.user_id = auth.uid()
    and coalesce(m.is_active, true) = true
));

grant select, insert, update, delete on public.erp_einvoice_settings to authenticated;
grant select, insert, update, delete on public.erp_einvoice_operations to authenticated;

drop policy if exists erp_einvoice_settings_member_access on public.erp_einvoice_settings;
drop policy if exists erp_einvoice_settings_select_finance on public.erp_einvoice_settings;
create policy erp_einvoice_settings_select_finance on public.erp_einvoice_settings for select to authenticated
using (public.erp_user_has_company_role(company_id,array['owner','admin','accountant']::text[]));
drop policy if exists erp_einvoice_settings_write_finance on public.erp_einvoice_settings;
create policy erp_einvoice_settings_write_finance on public.erp_einvoice_settings for all to authenticated
using (public.erp_user_has_company_role(company_id,array['owner','admin','accountant']::text[]))
with check (public.erp_user_has_company_role(company_id,array['owner','admin','accountant']::text[]));

drop policy if exists erp_einvoice_operations_member_access on public.erp_einvoice_operations;
drop policy if exists erp_einvoice_operations_select_member on public.erp_einvoice_operations;
create policy erp_einvoice_operations_select_member on public.erp_einvoice_operations for select to authenticated
using (public.erp_user_can_access_company(company_id));
drop policy if exists erp_einvoice_operations_insert_finance on public.erp_einvoice_operations;
create policy erp_einvoice_operations_insert_finance on public.erp_einvoice_operations for insert to authenticated
with check (public.erp_user_has_company_role(company_id,array['owner','admin','accountant','manager']::text[]));
drop policy if exists erp_einvoice_operations_update_finance on public.erp_einvoice_operations;
create policy erp_einvoice_operations_update_finance on public.erp_einvoice_operations for update to authenticated
using (public.erp_user_has_company_role(company_id,array['owner','admin','accountant']::text[]))
with check (public.erp_user_has_company_role(company_id,array['owner','admin','accountant']::text[]));
drop policy if exists erp_einvoice_operations_delete_admin on public.erp_einvoice_operations;
create policy erp_einvoice_operations_delete_admin on public.erp_einvoice_operations for delete to authenticated
using (public.erp_user_has_company_role(company_id,array['owner','admin']::text[]));
