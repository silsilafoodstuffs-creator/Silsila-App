-- Silsila Studio metadata and immutable revision history.
-- Review and apply manually; this file is not executed by the Flutter client.
begin;

create table if not exists public.erp_studio_designs (
  id uuid primary key default gen_random_uuid(),
  company_id uuid not null references public.erp_companies(id) on delete cascade,
  design_key text not null,
  name text not null check (length(trim(name)) between 1 and 160),
  design_kind text not null default 'screen'
    check (design_kind in ('screen','report','icon','tree','table','grid','form','component')),
  schema_version integer not null default 1 check (schema_version > 0),
  status text not null default 'draft'
    check (status in ('draft','review','approved','published','archived')),
  design_json jsonb not null default '{"schemaVersion":1,"nodes":[]}'::jsonb,
  binding_json jsonb not null default '{"mode":"unbound","sources":[]}'::jsonb,
  revision integer not null default 1 check (revision > 0),
  published_revision integer,
  created_by uuid not null default auth.uid() references auth.users(id),
  updated_by uuid not null default auth.uid() references auth.users(id),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (company_id, design_key),
  check (published_revision is null or published_revision <= revision)
);

create index if not exists erp_studio_designs_company_status_idx
  on public.erp_studio_designs(company_id, status, updated_at desc);

create table if not exists public.erp_studio_design_versions (
  id uuid primary key default gen_random_uuid(),
  design_id uuid not null references public.erp_studio_designs(id) on delete cascade,
  company_id uuid not null references public.erp_companies(id) on delete cascade,
  revision integer not null check (revision > 0),
  design_json jsonb not null,
  binding_json jsonb not null,
  change_note text,
  created_by uuid not null default auth.uid() references auth.users(id),
  created_at timestamptz not null default now(),
  unique (design_id, revision)
);

create index if not exists erp_studio_versions_company_design_idx
  on public.erp_studio_design_versions(company_id, design_id, revision desc);

create table if not exists public.erp_studio_audit_log (
  id bigint generated always as identity primary key,
  company_id uuid not null references public.erp_companies(id) on delete cascade,
  design_id uuid references public.erp_studio_designs(id) on delete set null,
  action_key text not null check (length(trim(action_key)) between 1 and 80),
  details jsonb not null default '{}'::jsonb,
  actor_user_id uuid not null default auth.uid() references auth.users(id),
  created_at timestamptz not null default now()
);

create index if not exists erp_studio_audit_company_created_idx
  on public.erp_studio_audit_log(company_id, created_at desc);

alter table public.erp_studio_designs enable row level security;
alter table public.erp_studio_design_versions enable row level security;
alter table public.erp_studio_audit_log enable row level security;

drop policy if exists erp_studio_designs_read_member on public.erp_studio_designs;
create policy erp_studio_designs_read_member on public.erp_studio_designs
for select to authenticated
using (public.erp_user_can_access_company(company_id));

drop policy if exists erp_studio_designs_insert_admin on public.erp_studio_designs;
create policy erp_studio_designs_insert_admin on public.erp_studio_designs
for insert to authenticated
with check (
  public.erp_user_has_company_role(company_id, array['owner','admin']::text[])
  and created_by = auth.uid() and updated_by = auth.uid()
);

drop policy if exists erp_studio_designs_update_admin on public.erp_studio_designs;
create policy erp_studio_designs_update_admin on public.erp_studio_designs
for update to authenticated
using (public.erp_user_has_company_role(company_id, array['owner','admin']::text[]))
with check (
  public.erp_user_has_company_role(company_id, array['owner','admin']::text[])
  and updated_by = auth.uid()
);

drop policy if exists erp_studio_designs_delete_admin on public.erp_studio_designs;
create policy erp_studio_designs_delete_admin on public.erp_studio_designs
for delete to authenticated
using (
  public.erp_user_has_company_role(company_id, array['owner','admin']::text[])
  and status in ('draft','archived')
);

drop policy if exists erp_studio_versions_read_member on public.erp_studio_design_versions;
create policy erp_studio_versions_read_member on public.erp_studio_design_versions
for select to authenticated
using (public.erp_user_can_access_company(company_id));

drop policy if exists erp_studio_versions_insert_admin on public.erp_studio_design_versions;
create policy erp_studio_versions_insert_admin on public.erp_studio_design_versions
for insert to authenticated
with check (
  public.erp_user_has_company_role(company_id, array['owner','admin']::text[])
  and created_by = auth.uid()
  and exists (
    select 1 from public.erp_studio_designs d
    where d.id = design_id and d.company_id = erp_studio_design_versions.company_id
  )
);

drop policy if exists erp_studio_audit_read_admin on public.erp_studio_audit_log;
create policy erp_studio_audit_read_admin on public.erp_studio_audit_log
for select to authenticated
using (public.erp_user_has_company_role(company_id, array['owner','admin']::text[]));

drop policy if exists erp_studio_audit_insert_admin on public.erp_studio_audit_log;
create policy erp_studio_audit_insert_admin on public.erp_studio_audit_log
for insert to authenticated
with check (
  public.erp_user_has_company_role(company_id, array['owner','admin']::text[])
  and actor_user_id = auth.uid()
);

revoke all on public.erp_studio_designs, public.erp_studio_design_versions, public.erp_studio_audit_log from anon;
grant select, insert, update, delete on public.erp_studio_designs to authenticated;
grant select, insert on public.erp_studio_design_versions to authenticated;
grant select, insert on public.erp_studio_audit_log to authenticated;
grant usage, select on sequence public.erp_studio_audit_log_id_seq to authenticated;

commit;
