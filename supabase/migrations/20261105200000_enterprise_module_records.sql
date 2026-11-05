create table if not exists public.erp_enterprise_module_records (
 id uuid primary key default gen_random_uuid(),
 company_id uuid not null references public.erp_companies(id) on delete cascade,
 module_key text not null check (module_key in ('assets','manufacturing','contracting','service_crm')),
 group_key text not null check (group_key in ('بيانات أساسية','حركات','تقارير')),
 page_key text not null,
 record_code text,
 title text not null,
 status text not null default 'active',
 reference_date date,
 due_date date,
 counterparty text,
 amount numeric(18,2) not null default 0,
 quantity numeric(18,4) not null default 0,
 details jsonb not null default '{}'::jsonb,
 notes text,
 created_by uuid references auth.users(id) on delete set null,
 created_at timestamptz not null default now(),
 updated_at timestamptz not null default now()
);
create index if not exists erp_enterprise_module_records_company_module_page_idx
 on public.erp_enterprise_module_records(company_id,module_key,page_key,created_at desc);
create index if not exists erp_enterprise_module_records_company_status_idx
 on public.erp_enterprise_module_records(company_id,module_key,status);
alter table public.erp_enterprise_module_records enable row level security;
drop policy if exists erp_enterprise_module_records_select on public.erp_enterprise_module_records;
create policy erp_enterprise_module_records_select on public.erp_enterprise_module_records
 for select to authenticated using (
  public.erp_user_has_company_role(company_id,array['owner','admin','manager']::text[])
  or exists(select 1 from public.erp_company_member_profiles p where p.company_id=erp_enterprise_module_records.company_id and p.user_id=(select auth.uid()))
 );
drop policy if exists erp_enterprise_module_records_insert on public.erp_enterprise_module_records;
create policy erp_enterprise_module_records_insert on public.erp_enterprise_module_records
 for insert to authenticated with check (
  public.erp_user_has_company_role(company_id,array['owner','admin','manager']::text[])
  or exists(select 1 from public.erp_company_member_profiles p where p.company_id=erp_enterprise_module_records.company_id and p.user_id=(select auth.uid()))
 );
drop policy if exists erp_enterprise_module_records_update on public.erp_enterprise_module_records;
create policy erp_enterprise_module_records_update on public.erp_enterprise_module_records
 for update to authenticated using (
  public.erp_user_has_company_role(company_id,array['owner','admin','manager']::text[])
  or exists(select 1 from public.erp_company_member_profiles p where p.company_id=erp_enterprise_module_records.company_id and p.user_id=(select auth.uid()))
 ) with check (
  public.erp_user_has_company_role(company_id,array['owner','admin','manager']::text[])
  or exists(select 1 from public.erp_company_member_profiles p where p.company_id=erp_enterprise_module_records.company_id and p.user_id=(select auth.uid()))
 );
drop policy if exists erp_enterprise_module_records_delete on public.erp_enterprise_module_records;
create policy erp_enterprise_module_records_delete on public.erp_enterprise_module_records
 for delete to authenticated using (
  public.erp_user_has_company_role(company_id,array['owner','admin']::text[])
 );
grant select,insert,update,delete on public.erp_enterprise_module_records to authenticated;