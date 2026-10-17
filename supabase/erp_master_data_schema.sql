-- Silsila ERP master-data extensions: alternate units, party contacts, and price lists.
-- Apply only after erp_schema.sql succeeds. RLS is enabled below; apply
-- erp_security_membership.sql for company-scoped policies before client access.

create table if not exists public.erp_item_units (
  id uuid primary key default gen_random_uuid(),
  company_id uuid not null references public.erp_companies(id) on delete restrict,
  item_id uuid not null references public.erp_items(id) on delete restrict,
  unit_code text not null,
  unit_name text not null,
  conversion_factor numeric(14,6) not null check (conversion_factor > 0),
  barcode text,
  is_base_unit boolean not null default false,
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (item_id, unit_code)
);

create unique index if not exists erp_item_units_one_base_idx
  on public.erp_item_units(item_id) where is_base_unit;
create unique index if not exists erp_item_units_barcode_idx
  on public.erp_item_units(company_id, barcode) where barcode is not null;
create index if not exists erp_item_units_company_item_idx
  on public.erp_item_units(company_id, item_id);

create table if not exists public.erp_party_contacts (
  id uuid primary key default gen_random_uuid(),
  company_id uuid not null references public.erp_companies(id) on delete restrict,
  party_id uuid not null references public.erp_parties(id) on delete cascade,
  contact_name text not null,
  job_title text,
  phone text,
  whatsapp text,
  email text,
  is_primary boolean not null default false,
  notes text,
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists erp_party_contacts_party_idx
  on public.erp_party_contacts(company_id, party_id);
create unique index if not exists erp_party_contacts_one_primary_idx
  on public.erp_party_contacts(party_id) where is_primary and is_active;

create table if not exists public.erp_price_lists (
  id uuid primary key default gen_random_uuid(),
  company_id uuid not null references public.erp_companies(id) on delete restrict,
  price_list_code text not null,
  price_list_name text not null,
  price_kind text not null check (price_kind in ('sale', 'purchase')),
  currency_code char(3) not null default 'EGP',
  starts_on date,
  ends_on date,
  is_default boolean not null default false,
  is_active boolean not null default true,
  notes text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (company_id, price_list_code),
  check (ends_on is null or starts_on is null or ends_on >= starts_on)
);

create unique index if not exists erp_price_lists_one_default_idx
  on public.erp_price_lists(company_id, price_kind) where is_default and is_active;

create table if not exists public.erp_price_list_lines (
  id uuid primary key default gen_random_uuid(),
  company_id uuid not null references public.erp_companies(id) on delete restrict,
  price_list_id uuid not null references public.erp_price_lists(id) on delete cascade,
  item_id uuid not null references public.erp_items(id) on delete restrict,
  item_unit_id uuid references public.erp_item_units(id) on delete restrict,
  min_quantity numeric(14,3) not null default 1 check (min_quantity > 0),
  unit_price numeric(14,4) not null check (unit_price >= 0),
  discount_percent numeric(7,4) not null default 0
    check (discount_percent >= 0 and discount_percent <= 100),
  starts_on date,
  ends_on date,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  check (ends_on is null or starts_on is null or ends_on >= starts_on)
);

create index if not exists erp_price_list_lines_lookup_idx
  on public.erp_price_list_lines(company_id, price_list_id, item_id, min_quantity);

create table if not exists public.erp_party_price_lists (
  id uuid primary key default gen_random_uuid(),
  company_id uuid not null references public.erp_companies(id) on delete restrict,
  party_id uuid not null references public.erp_parties(id) on delete cascade,
  price_list_id uuid not null references public.erp_price_lists(id) on delete restrict,
  starts_on date,
  ends_on date,
  created_at timestamptz not null default now(),
  unique (party_id, price_list_id),
  check (ends_on is null or starts_on is null or ends_on >= starts_on)
);

create index if not exists erp_party_price_lists_party_idx
  on public.erp_party_price_lists(company_id, party_id);

do $$
declare
  t text;
begin
  foreach t in array array[
    'erp_item_units',
    'erp_party_contacts',
    'erp_price_lists',
    'erp_price_list_lines',
    'erp_party_price_lists'
  ]
  loop
    execute format('alter table public.%I enable row level security', t);
  end loop;
end;
$$;

drop trigger if exists erp_item_units_updated_at on public.erp_item_units;
create trigger erp_item_units_updated_at before update on public.erp_item_units
for each row execute function public.erp_set_updated_at();

drop trigger if exists erp_party_contacts_updated_at on public.erp_party_contacts;
create trigger erp_party_contacts_updated_at before update on public.erp_party_contacts
for each row execute function public.erp_set_updated_at();

drop trigger if exists erp_price_lists_updated_at on public.erp_price_lists;
create trigger erp_price_lists_updated_at before update on public.erp_price_lists
for each row execute function public.erp_set_updated_at();

drop trigger if exists erp_price_list_lines_updated_at on public.erp_price_list_lines;
create trigger erp_price_list_lines_updated_at before update on public.erp_price_list_lines
for each row execute function public.erp_set_updated_at();

-- IMPORTANT:
-- 1) This schema does not grant access. Add restrictive tenant-aware RLS policies first.
-- 2) Validate that every item, party, unit and price list belongs to the same company
--    in trusted server-side operations; ordinary foreign keys alone do not enforce that.
-- 3) The base unit in erp_items remains authoritative until migration/backfill rules
--    for erp_item_units are implemented.
