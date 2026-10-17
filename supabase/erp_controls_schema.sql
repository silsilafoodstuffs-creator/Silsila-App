-- Silsila ERP: company-scoped permissions, pricing policies, delegate assignments and transaction restrictions.
-- Review and apply only after confirming the base schema and production tenant/RLS model.
-- RLS is enabled without permissive policies intentionally. Add reviewed policies before production use.
-- This migration does not grant access and does not modify live data by itself.

create table if not exists public.erp_role_permissions (
  id uuid primary key default gen_random_uuid(),
  company_id uuid not null references public.erp_companies(id) on delete restrict,
  role_key text not null,
  module_key text not null,
  permission_key text not null,
  is_enabled boolean not null default false,
  updated_by uuid references auth.users(id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique(company_id, role_key, module_key, permission_key)
);

create table if not exists public.erp_pricing_policies (
  id uuid primary key default gen_random_uuid(),
  company_id uuid not null references public.erp_companies(id) on delete restrict,
  policy_name text not null,
  item_id uuid,
  adjustment_type text not null check (adjustment_type in ('percent','amount')),
  adjustment_direction text not null check (adjustment_direction in ('increase','decrease')),
  adjustment_value numeric(18,4) not null default 0 check (adjustment_value >= 0),
  base_price numeric(18,4) check (base_price is null or base_price >= 0),
  price_floor numeric(18,4) check (price_floor is null or price_floor >= 0),
  max_invoice_discount_percent numeric(7,4) not null default 0
    check (max_invoice_discount_percent between 0 and 100),
  max_item_discount_percent numeric(7,4) not null default 0
    check (max_item_discount_percent between 0 and 100),
  is_active boolean not null default true,
  created_by uuid references auth.users(id) on delete set null,
  updated_by uuid references auth.users(id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists erp_pricing_policies_company_item_idx
  on public.erp_pricing_policies(company_id, item_id, is_active);

create table if not exists public.erp_item_delegate_assignments (
  id uuid primary key default gen_random_uuid(),
  company_id uuid not null references public.erp_companies(id) on delete restrict,
  item_id uuid not null,
  delegate_id uuid not null,
  is_allowed boolean not null default true,
  updated_by uuid references auth.users(id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique(company_id, item_id, delegate_id)
);

create table if not exists public.erp_transaction_restrictions (
  id uuid primary key default gen_random_uuid(),
  company_id uuid not null references public.erp_companies(id) on delete restrict,
  action_key text not null check (action_key in ('stop_sale','stop_purchase','sale_limit')),
  target_type text not null check (target_type in ('item','invoice','customer','delegate')),
  item_id uuid,
  customer_id uuid,
  delegate_id uuid,
  document_id uuid,
  maximum_quantity numeric(18,4) check (maximum_quantity is null or maximum_quantity >= 0),
  is_active boolean not null default true,
  created_by uuid references auth.users(id) on delete set null,
  updated_by uuid references auth.users(id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  check (
    (target_type = 'item' and item_id is not null) or
    (target_type = 'invoice' and document_id is not null) or
    (target_type = 'customer' and customer_id is not null) or
    (target_type = 'delegate' and delegate_id is not null)
  )
);

create index if not exists erp_transaction_restrictions_lookup_idx
  on public.erp_transaction_restrictions(company_id, action_key, target_type, is_active);

alter table public.erp_role_permissions enable row level security;
alter table public.erp_pricing_policies enable row level security;
alter table public.erp_item_delegate_assignments enable row level security;
alter table public.erp_transaction_restrictions enable row level security;

comment on table public.erp_role_permissions is
  'Company-scoped role permissions. Add restrictive RLS policies and enforce critical actions server-side.';
comment on table public.erp_pricing_policies is
  'Company-scoped pricing and discount rules; validate item IDs and price limits against the item master.';
comment on table public.erp_item_delegate_assignments is
  'Company-scoped item-to-sales-delegate assignment rules.';
comment on table public.erp_transaction_restrictions is
  'Company-scoped sale/purchase restrictions; invoice write paths must enforce these rules.';
