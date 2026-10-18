-- Generic configurable ERP workspace records.
-- Apply after supabase/erp_schema.sql and supabase/erp_security_membership.sql.
-- Financial, inventory, payroll, and legal documents must use their dedicated tables.
begin;

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
for select to authenticated using (public.erp_user_can_access_company(company_id));

drop policy if exists erp_workspace_records_insert_operator on public.erp_workspace_records;
create policy erp_workspace_records_insert_operator on public.erp_workspace_records
for insert to authenticated with check (
  public.erp_user_has_company_role(company_id, array['owner','admin','accountant','manager','operator']::text[])
  and (created_by is null or created_by = auth.uid())
  and (updated_by is null or updated_by = auth.uid())
);

drop policy if exists erp_workspace_records_update_operator on public.erp_workspace_records;
create policy erp_workspace_records_update_operator on public.erp_workspace_records
for update to authenticated
using (public.erp_user_has_company_role(company_id, array['owner','admin','accountant','manager','operator']::text[]))
with check (
  public.erp_user_has_company_role(company_id, array['owner','admin','accountant','manager','operator']::text[])
  and (updated_by is null or updated_by = auth.uid())
);

drop policy if exists erp_workspace_records_delete_admin on public.erp_workspace_records;
create policy erp_workspace_records_delete_admin on public.erp_workspace_records
for delete to authenticated
using (public.erp_user_has_company_role(company_id, array['owner','admin']::text[]));

grant select, insert, update, delete on public.erp_workspace_records to authenticated;
commit;
