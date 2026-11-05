create table if not exists public.erp_business_suite_records (
  id uuid primary key default gen_random_uuid(),
  company_id uuid not null references public.erp_companies(id) on delete cascade,
  module_key text not null check (module_key in ('fixed_assets','manufacturing','contracting','customer_service')),
  record_type text not null,
  record_code text not null,
  name text not null,
  status text not null default 'draft',
  record_date date,
  due_date date,
  quantity numeric(18,4),
  amount numeric(18,2),
  details jsonb not null default '{}'::jsonb,
  related_record_id uuid,
  created_by uuid references auth.users(id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint erp_business_suite_records_code_unique unique(company_id,module_key,record_type,record_code),
  constraint erp_business_suite_records_dates_check check (due_date is null or record_date is null or due_date >= record_date),
  constraint erp_business_suite_records_amount_check check (amount is null or amount >= 0),
  constraint erp_business_suite_records_quantity_check check (quantity is null or quantity >= 0)
);
create index if not exists erp_business_suite_records_company_module_type_idx
  on public.erp_business_suite_records(company_id,module_key,record_type,record_date desc);
create index if not exists erp_business_suite_records_details_gin_idx
  on public.erp_business_suite_records using gin(details);
alter table public.erp_business_suite_records enable row level security;
drop policy if exists erp_business_suite_records_select_company on public.erp_business_suite_records;
create policy erp_business_suite_records_select_company on public.erp_business_suite_records
for select to authenticated using (
  public.erp_user_has_company_role(company_id,array['owner','admin','manager']::text[])
  or exists(select 1 from public.erp_company_member_profiles p where p.company_id=erp_business_suite_records.company_id and p.user_id=(select auth.uid()))
);
drop policy if exists erp_business_suite_records_insert_company on public.erp_business_suite_records;
create policy erp_business_suite_records_insert_company on public.erp_business_suite_records
for insert to authenticated with check (
  public.erp_user_has_company_role(company_id,array['owner','admin','manager']::text[])
  or exists(select 1 from public.erp_company_member_profiles p where p.company_id=erp_business_suite_records.company_id and p.user_id=(select auth.uid()))
);
drop policy if exists erp_business_suite_records_update_company on public.erp_business_suite_records;
create policy erp_business_suite_records_update_company on public.erp_business_suite_records
for update to authenticated using (
  public.erp_user_has_company_role(company_id,array['owner','admin','manager']::text[])
  or exists(select 1 from public.erp_company_member_profiles p where p.company_id=erp_business_suite_records.company_id and p.user_id=(select auth.uid()))
) with check (
  public.erp_user_has_company_role(company_id,array['owner','admin','manager']::text[])
  or exists(select 1 from public.erp_company_member_profiles p where p.company_id=erp_business_suite_records.company_id and p.user_id=(select auth.uid()))
);
drop policy if exists erp_business_suite_records_delete_company on public.erp_business_suite_records;
create policy erp_business_suite_records_delete_company on public.erp_business_suite_records
for delete to authenticated using (public.erp_user_has_company_role(company_id,array['owner','admin']::text[]));
grant select,insert,update,delete on public.erp_business_suite_records to authenticated;
drop trigger if exists erp_business_suite_records_updated_at on public.erp_business_suite_records;
create trigger erp_business_suite_records_updated_at before update on public.erp_business_suite_records for each row execute function public.erp_set_updated_at();
