-- Silsila ERP inventory controls: stock counts, reorder thresholds, batch balances and expiry alerts.
-- Apply only after supabase/erp_schema.sql and supabase/erp_operations_schema.sql succeed.
-- RLS is enabled without permissive policies; posting counts/adjustments must happen through a trusted backend.

create table if not exists public.erp_stock_counts (
  id uuid primary key default gen_random_uuid(),
  company_id uuid not null references public.erp_companies(id) on delete restrict,
  branch_id uuid references public.erp_branches(id) on delete restrict,
  warehouse_id uuid not null references public.erp_warehouses(id) on delete restrict,
  count_number text not null,
  count_date date not null default current_date,
  count_scope text not null default 'full'
    check (count_scope in ('full','cycle','spot')),
  status text not null default 'draft'
    check (status in ('draft','counting','review','approved','posted','cancelled')),
  notes text,
  created_by uuid references auth.users(id) on delete set null,
  approved_by uuid references auth.users(id) on delete set null,
  approved_at timestamptz,
  posted_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (company_id, count_number)
);

create table if not exists public.erp_stock_count_lines (
  id uuid primary key default gen_random_uuid(),
  count_id uuid not null references public.erp_stock_counts(id) on delete cascade,
  item_id uuid not null references public.erp_items(id) on delete restrict,
  batch_number text,
  expiry_date date,
  system_quantity numeric(14,3) not null default 0,
  counted_quantity numeric(14,3),
  variance_quantity numeric(14,3)
    generated always as (counted_quantity - system_quantity) stored,
  unit_cost numeric(14,4) not null default 0 check (unit_cost >= 0),
  notes text,
  counted_by uuid references auth.users(id) on delete set null,
  counted_at timestamptz,
  created_at timestamptz not null default now(),
  check (system_quantity >= 0),
  check (counted_quantity is null or counted_quantity >= 0),
  unique (count_id, item_id, batch_number)
);

create table if not exists public.erp_reorder_rules (
  id uuid primary key default gen_random_uuid(),
  company_id uuid not null references public.erp_companies(id) on delete restrict,
  branch_id uuid references public.erp_branches(id) on delete restrict,
  warehouse_id uuid not null references public.erp_warehouses(id) on delete restrict,
  item_id uuid not null references public.erp_items(id) on delete restrict,
  minimum_quantity numeric(14,3) not null default 0 check (minimum_quantity >= 0),
  target_quantity numeric(14,3) not null default 0 check (target_quantity >= 0),
  reorder_quantity numeric(14,3) not null default 0 check (reorder_quantity >= 0),
  is_active boolean not null default true,
  notes text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (company_id, warehouse_id, item_id),
  check (target_quantity >= minimum_quantity)
);

create index if not exists erp_stock_counts_warehouse_date_idx
  on public.erp_stock_counts(company_id, warehouse_id, count_date desc);
create index if not exists erp_stock_counts_status_idx
  on public.erp_stock_counts(company_id, status, count_date desc);
create index if not exists erp_stock_count_lines_item_idx
  on public.erp_stock_count_lines(item_id, count_id);
create index if not exists erp_reorder_rules_lookup_idx
  on public.erp_reorder_rules(company_id, warehouse_id, is_active, item_id);

-- Lot-level balances are derived from the immutable movement ledger.
-- Outgoing movements should carry the same batch_number as the lot they consume.
create or replace view public.erp_inventory_batch_balances as
select
  company_id,
  branch_id,
  warehouse_id,
  item_id,
  batch_number,
  expiry_date,
  sum(quantity_in - quantity_out) as quantity_on_hand
from public.erp_inventory_movements
where batch_number is not null or expiry_date is not null
group by company_id, branch_id, warehouse_id, item_id, batch_number, expiry_date
having sum(quantity_in - quantity_out) > 0;

-- Operational alert view: the app/backend can filter this by authorized company/branch.
create or replace view public.erp_inventory_expiry_alerts as
select
  company_id,
  branch_id,
  warehouse_id,
  item_id,
  batch_number,
  expiry_date,
  quantity_on_hand,
  (expiry_date - current_date) as days_until_expiry,
  case
    when expiry_date < current_date then 'expired'
    when expiry_date <= current_date + 7 then 'expires_within_7_days'
    when expiry_date <= current_date + 30 then 'expires_within_30_days'
    else 'valid'
  end as expiry_status
from public.erp_inventory_batch_balances
where expiry_date is not null
  and expiry_date <= current_date + 30;

-- The balance view is a derived convenience; low-stock alerts compare it with reorder rules.
create or replace view public.erp_inventory_reorder_alerts as
select
  r.company_id,
  r.branch_id,
  r.warehouse_id,
  r.item_id,
  r.minimum_quantity,
  r.target_quantity,
  r.reorder_quantity,
  coalesce(b.quantity_on_hand, 0) as quantity_on_hand,
  greatest(r.target_quantity - coalesce(b.quantity_on_hand, 0), r.reorder_quantity, 0) as suggested_order_quantity
from public.erp_reorder_rules r
left join (
  select company_id, branch_id, warehouse_id, item_id, sum(quantity_in - quantity_out) as quantity_on_hand
  from public.erp_inventory_movements
  group by company_id, branch_id, warehouse_id, item_id
) b on b.company_id = r.company_id
  and b.warehouse_id = r.warehouse_id
  and b.item_id = r.item_id
  and b.branch_id is not distinct from r.branch_id
where r.is_active
  and coalesce(b.quantity_on_hand, 0) <= r.minimum_quantity;

alter table public.erp_stock_counts enable row level security;
alter table public.erp_stock_count_lines enable row level security;
alter table public.erp_reorder_rules enable row level security;

drop trigger if exists erp_stock_counts_updated_at on public.erp_stock_counts;
create trigger erp_stock_counts_updated_at before update on public.erp_stock_counts
for each row execute function public.erp_set_updated_at();

drop trigger if exists erp_reorder_rules_updated_at on public.erp_reorder_rules;
create trigger erp_reorder_rules_updated_at before update on public.erp_reorder_rules
for each row execute function public.erp_set_updated_at();

-- Before production:
-- 1) Add tenant/branch-aware RLS policies for tables and views.
-- 2) Enforce company/branch/warehouse/item consistency in trusted server-side writes.
-- 3) Only a trusted posting operation should write stock movements for approved counts.
-- 4) Define and enforce lot allocation/FEFO rules for outgoing stock movements.
-- 5) Views are not substitutes for authorization; expose them only through secured access paths.
