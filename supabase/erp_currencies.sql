create table if not exists public.erp_currencies (
 id uuid primary key default gen_random_uuid(),
 company_id uuid not null references public.erp_companies(id) on delete cascade,
 currency_code varchar(12) not null,
 currency_name_ar varchar(100) not null,
 currency_symbol varchar(10) not null,
 is_active boolean not null default true,
 created_at timestamptz not null default now(),
 updated_at timestamptz not null default now(),
 unique(company_id, currency_code)
);
create index if not exists erp_currencies_company_active_idx on public.erp_currencies(company_id,is_active,currency_code);
alter table public.erp_currencies enable row level security;
drop policy if exists erp_currencies_member_select on public.erp_currencies;
create policy erp_currencies_member_select on public.erp_currencies for select to authenticated using (
 exists(select 1 from public.erp_company_members m where m.company_id=erp_currencies.company_id and m.user_id=auth.uid() and m.is_active=true));
drop policy if exists erp_currencies_member_insert on public.erp_currencies;
create policy erp_currencies_member_insert on public.erp_currencies for insert to authenticated with check (
 exists(select 1 from public.erp_company_members m where m.company_id=erp_currencies.company_id and m.user_id=auth.uid() and m.is_active=true));
drop policy if exists erp_currencies_member_update on public.erp_currencies;
create policy erp_currencies_member_update on public.erp_currencies for update to authenticated using (
 exists(select 1 from public.erp_company_members m where m.company_id=erp_currencies.company_id and m.user_id=auth.uid() and m.is_active=true))
 with check (exists(select 1 from public.erp_company_members m where m.company_id=erp_currencies.company_id and m.user_id=auth.uid() and m.is_active=true));
grant select,insert,update on public.erp_currencies to authenticated;
