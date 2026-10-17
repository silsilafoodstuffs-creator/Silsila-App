-- Silsila ERP foundation schema
-- Apply manually in Supabase SQL Editor after reviewing the target project.
-- RLS is enabled without permissive policies: browser/mobile clients cannot access
-- these tables until authenticated company/branch authorization policies are added.

create extension if not exists pgcrypto;

create or replace function public.erp_set_updated_at()
returns trigger
language plpgsql
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

create table if not exists public.erp_companies (
  id uuid primary key default gen_random_uuid(),
  legal_name text not null,
  trade_name text,
  tax_number text,
  commercial_register text,
  phone text,
  email text,
  address text,
  base_currency char(3) not null default 'EGP',
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.erp_branches (
  id uuid primary key default gen_random_uuid(),
  company_id uuid not null references public.erp_companies(id) on delete restrict,
  branch_code text not null,
  branch_name text not null,
  phone text,
  address text,
  is_main boolean not null default false,
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (company_id, branch_code)
);

create table if not exists public.erp_fiscal_periods (
  id uuid primary key default gen_random_uuid(),
  company_id uuid not null references public.erp_companies(id) on delete restrict,
  period_name text not null,
  starts_on date not null,
  ends_on date not null,
  status text not null default 'open' check (status in ('open', 'closed')),
  created_at timestamptz not null default now(),
  check (ends_on >= starts_on),
  unique (company_id, period_name)
);

create table if not exists public.erp_accounts (
  id uuid primary key default gen_random_uuid(),
  company_id uuid not null references public.erp_companies(id) on delete restrict,
  parent_id uuid references public.erp_accounts(id) on delete restrict,
  account_code text not null,
  account_name text not null,
  account_type text not null check (account_type in ('asset','liability','equity','revenue','expense')),
  normal_balance text not null check (normal_balance in ('debit','credit')),
  is_postable boolean not null default false,
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (company_id, account_code)
);

create table if not exists public.erp_cashboxes (
  id uuid primary key default gen_random_uuid(),
  company_id uuid not null references public.erp_companies(id) on delete restrict,
  branch_id uuid references public.erp_branches(id) on delete restrict,
  account_id uuid references public.erp_accounts(id) on delete restrict,
  cashbox_code text not null,
  cashbox_name text not null,
  is_bank_account boolean not null default false,
  bank_name text,
  account_number_masked text,
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (company_id, cashbox_code)
);

create table if not exists public.erp_warehouses (
  id uuid primary key default gen_random_uuid(),
  company_id uuid not null references public.erp_companies(id) on delete restrict,
  branch_id uuid references public.erp_branches(id) on delete restrict,
  warehouse_code text not null,
  warehouse_name text not null,
  address text,
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (company_id, warehouse_code)
);

create table if not exists public.erp_item_groups (
  id uuid primary key default gen_random_uuid(),
  company_id uuid not null references public.erp_companies(id) on delete restrict,
  parent_id uuid references public.erp_item_groups(id) on delete restrict,
  group_code text not null,
  group_name text not null,
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  unique (company_id, group_code)
);

create table if not exists public.erp_items (
  id uuid primary key default gen_random_uuid(),
  company_id uuid not null references public.erp_companies(id) on delete restrict,
  group_id uuid references public.erp_item_groups(id) on delete restrict,
  item_code text not null,
  barcode text,
  item_name text not null,
  base_unit text not null default 'وحدة',
  purchase_price numeric(14,2) not null default 0 check (purchase_price >= 0),
  sale_price numeric(14,2) not null default 0 check (sale_price >= 0),
  reorder_level numeric(14,3) not null default 0 check (reorder_level >= 0),
  expiry_tracking boolean not null default false,
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (company_id, item_code)
);

create table if not exists public.erp_parties (
  id uuid primary key default gen_random_uuid(),
  company_id uuid not null references public.erp_companies(id) on delete restrict,
  party_code text not null,
  party_name text not null,
  party_kind text not null check (party_kind in ('supplier','customer','both')),
  phone text,
  whatsapp text,
  email text,
  tax_number text,
  address text,
  governorate text,
  district text,
  credit_limit numeric(14,2) not null default 0 check (credit_limit >= 0),
  opening_balance numeric(14,2) not null default 0,
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (company_id, party_code)
);

create table if not exists public.erp_journal_entries (
  id uuid primary key default gen_random_uuid(),
  company_id uuid not null references public.erp_companies(id) on delete restrict,
  branch_id uuid references public.erp_branches(id) on delete restrict,
  fiscal_period_id uuid references public.erp_fiscal_periods(id) on delete restrict,
  entry_number bigint generated by default as identity,
  entry_date date not null default current_date,
  description text not null,
  source_type text not null default 'manual',
  source_id uuid,
  status text not null default 'draft' check (status in ('draft','posted','reversed')),
  created_by uuid references auth.users(id) on delete set null,
  posted_by uuid references auth.users(id) on delete set null,
  posted_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (company_id, entry_number)
);

create table if not exists public.erp_journal_lines (
  id uuid primary key default gen_random_uuid(),
  entry_id uuid not null references public.erp_journal_entries(id) on delete cascade,
  account_id uuid not null references public.erp_accounts(id) on delete restrict,
  description text,
  debit numeric(14,2) not null default 0 check (debit >= 0),
  credit numeric(14,2) not null default 0 check (credit >= 0),
  party_id uuid references public.erp_parties(id) on delete restrict,
  branch_id uuid references public.erp_branches(id) on delete restrict,
  created_at timestamptz not null default now(),
  check ((debit > 0 and credit = 0) or (credit > 0 and debit = 0))
);

create index if not exists erp_branches_company_idx on public.erp_branches(company_id);
create index if not exists erp_accounts_parent_idx on public.erp_accounts(parent_id);
create index if not exists erp_items_group_idx on public.erp_items(group_id);
create index if not exists erp_parties_kind_idx on public.erp_parties(company_id, party_kind);
create index if not exists erp_journal_date_idx on public.erp_journal_entries(company_id, entry_date);
create index if not exists erp_journal_status_idx on public.erp_journal_entries(status);
create index if not exists erp_journal_lines_account_idx on public.erp_journal_lines(account_id);
create index if not exists erp_journal_lines_entry_idx on public.erp_journal_lines(entry_id);

do $$
declare
  t text;
begin
  foreach t in array array[
    'erp_companies','erp_branches','erp_fiscal_periods','erp_accounts',
    'erp_cashboxes','erp_warehouses','erp_item_groups','erp_items',
    'erp_parties','erp_journal_entries','erp_journal_lines'
  ]
  loop
    execute format('alter table public.%I enable row level security', t);
  end loop;
end;
$$;

drop trigger if exists erp_companies_updated_at on public.erp_companies;
create trigger erp_companies_updated_at before update on public.erp_companies
for each row execute function public.erp_set_updated_at();
drop trigger if exists erp_branches_updated_at on public.erp_branches;
create trigger erp_branches_updated_at before update on public.erp_branches
for each row execute function public.erp_set_updated_at();
drop trigger if exists erp_accounts_updated_at on public.erp_accounts;
create trigger erp_accounts_updated_at before update on public.erp_accounts
for each row execute function public.erp_set_updated_at();
drop trigger if exists erp_cashboxes_updated_at on public.erp_cashboxes;
create trigger erp_cashboxes_updated_at before update on public.erp_cashboxes
for each row execute function public.erp_set_updated_at();
drop trigger if exists erp_warehouses_updated_at on public.erp_warehouses;
create trigger erp_warehouses_updated_at before update on public.erp_warehouses
for each row execute function public.erp_set_updated_at();
drop trigger if exists erp_items_updated_at on public.erp_items;
create trigger erp_items_updated_at before update on public.erp_items
for each row execute function public.erp_set_updated_at();
drop trigger if exists erp_parties_updated_at on public.erp_parties;
create trigger erp_parties_updated_at before update on public.erp_parties
for each row execute function public.erp_set_updated_at();
drop trigger if exists erp_journal_entries_updated_at on public.erp_journal_entries;
create trigger erp_journal_entries_updated_at before update on public.erp_journal_entries
for each row execute function public.erp_set_updated_at();
