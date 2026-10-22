-- Server-side immutable snapshots used before selective ERP workspace clearing.
-- Apply after erp_schema.sql, erp_security_membership.sql and erp_workspace_records.sql.
begin;

create table if not exists public.erp_data_backups (
  id uuid primary key default gen_random_uuid(),
  company_id uuid not null references public.erp_companies(id) on delete restrict,
  backup_id text not null,
  backup_type text not null default 'manual',
  selected_pages text[] not null default '{}'::text[],
  record_count integer not null default 0 check (record_count >= 0),
  payload jsonb not null check (jsonb_typeof(payload) = 'object'),
  created_by uuid references auth.users(id) on delete set null,
  created_at timestamptz not null default now(),
  unique(company_id, backup_id)
);

create index if not exists erp_data_backups_company_created_idx
  on public.erp_data_backups(company_id, created_at desc);

alter table public.erp_data_backups enable row level security;
drop policy if exists erp_data_backups_select_admin on public.erp_data_backups;
create policy erp_data_backups_select_admin on public.erp_data_backups
for select to authenticated
using (public.erp_user_has_company_role(company_id, array['owner','admin']::text[]));

drop policy if exists erp_data_backups_insert_admin on public.erp_data_backups;
create policy erp_data_backups_insert_admin on public.erp_data_backups
for insert to authenticated
with check (
  public.erp_user_has_company_role(company_id, array['owner','admin']::text[])
  and (created_by is null or created_by = auth.uid())
);

-- Backups are intentionally immutable from the client: no update/delete policies.
grant select, insert on public.erp_data_backups to authenticated;
commit;
