-- Silsila ERP operational documents: purchases, sales, and stock movements.
-- Run only after erp_schema.sql has been applied successfully.
-- RLS is enabled without client-access policies until tenant/branch permissions are configured.

create table if not exists public.erp_purchase_documents (
  id uuid primary key default gen_random_uuid(),
  company_id uuid not null references public.erp_companies(id) on delete restrict,
  branch_id uuid references public.erp_branches(id) on delete restrict,
  warehouse_id uuid references public.erp_warehouses(id) on delete restrict,
  supplier_id uuid not null references public.erp_parties(id) on delete restrict,
  document_number text not null,
  document_date date not null default current_date,
  due_date date,
  document_type text not null default 'invoice'
    check (document_type in ('order','receipt','invoice','return')),
  status text not null default 'draft'
    check (status in ('draft','approved','posted','cancelled')),
  subtotal numeric(14,2) not null default 0 check (subtotal >= 0),
  discount_total numeric(14,2) not null default 0 check (discount_total >= 0),
  tax_total numeric(14,2) not null default 0 check (tax_total >= 0),
  grand_total numeric(14,2) not null default 0 check (grand_total >= 0),
  paid_total numeric(14,2) not null default 0 check (paid_total >= 0),
  notes text,
  created_by uuid references auth.users(id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (company_id, document_number),
  check (paid_total <= grand_total)
);

create table if not exists public.erp_purchase_lines (
  id uuid primary key default gen_random_uuid(),
  document_id uuid not null references public.erp_purchase_documents(id) on delete cascade,
  item_id uuid not null references public.erp_items(id) on delete restrict,
  quantity numeric(14,3) not null check (quantity > 0),
  unit_price numeric(14,4) not null check (unit_price >= 0),
  discount_amount numeric(14,2) not null default 0 check (discount_amount >= 0),
  tax_amount numeric(14,2) not null default 0 check (tax_amount >= 0),
  line_total numeric(14,2) not null check (line_total >= 0),
  batch_number text,
  expiry_date date,
  created_at timestamptz not null default now()
);

create table if not exists public.erp_sales_documents (
  id uuid primary key default gen_random_uuid(),
  company_id uuid not null references public.erp_companies(id) on delete restrict,
  branch_id uuid references public.erp_branches(id) on delete restrict,
  warehouse_id uuid references public.erp_warehouses(id) on delete restrict,
  customer_id uuid not null references public.erp_parties(id) on delete restrict,
  document_number text not null,
  document_date date not null default current_date,
  due_date date,
  document_type text not null default 'invoice'
    check (document_type in ('quotation','order','delivery','invoice','return')),
  status text not null default 'draft'
    check (status in ('draft','approved','posted','cancelled')),
  subtotal numeric(14,2) not null default 0 check (subtotal >= 0),
  discount_total numeric(14,2) not null default 0 check (discount_total >= 0),
  tax_total numeric(14,2) not null default 0 check (tax_total >= 0),
  grand_total numeric(14,2) not null default 0 check (grand_total >= 0),
  paid_total numeric(14,2) not null default 0 check (paid_total >= 0),
  delivery_address text,
  notes text,
  created_by uuid references auth.users(id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (company_id, document_number),
  check (paid_total <= grand_total)
);

create table if not exists public.erp_sales_lines (
  id uuid primary key default gen_random_uuid(),
  document_id uuid not null references public.erp_sales_documents(id) on delete cascade,
  item_id uuid not null references public.erp_items(id) on delete restrict,
  quantity numeric(14,3) not null check (quantity > 0),
  unit_price numeric(14,4) not null check (unit_price >= 0),
  discount_amount numeric(14,2) not null default 0 check (discount_amount >= 0),
  tax_amount numeric(14,2) not null default 0 check (tax_amount >= 0),
  line_total numeric(14,2) not null check (line_total >= 0),
  batch_number text,
  expiry_date date,
  created_at timestamptz not null default now()
);

create table if not exists public.erp_inventory_movements (
  id uuid primary key default gen_random_uuid(),
  company_id uuid not null references public.erp_companies(id) on delete restrict,
  branch_id uuid references public.erp_branches(id) on delete restrict,
  warehouse_id uuid not null references public.erp_warehouses(id) on delete restrict,
  item_id uuid not null references public.erp_items(id) on delete restrict,
  movement_date timestamptz not null default now(),
  movement_type text not null
    check (movement_type in ('opening','purchase_receipt','sales_issue','customer_return','supplier_return','transfer_in','transfer_out','adjustment','waste')),
  quantity_in numeric(14,3) not null default 0 check (quantity_in >= 0),
  quantity_out numeric(14,3) not null default 0 check (quantity_out >= 0),
  unit_cost numeric(14,4) not null default 0 check (unit_cost >= 0),
  reference_type text,
  reference_id uuid,
  batch_number text,
  expiry_date date,
  notes text,
  created_by uuid references auth.users(id) on delete set null,
  created_at timestamptz not null default now(),
  check ((quantity_in > 0 and quantity_out = 0) or (quantity_out > 0 and quantity_in = 0))
);

create index if not exists erp_purchase_date_idx
  on public.erp_purchase_documents(company_id, document_date);
create index if not exists erp_purchase_supplier_idx
  on public.erp_purchase_documents(supplier_id, status);
create index if not exists erp_purchase_lines_item_idx
  on public.erp_purchase_lines(item_id);
create index if not exists erp_sales_date_idx
  on public.erp_sales_documents(company_id, document_date);
create index if not exists erp_sales_customer_idx
  on public.erp_sales_documents(customer_id, status);
create index if not exists erp_sales_lines_item_idx
  on public.erp_sales_lines(item_id);
create index if not exists erp_stock_balance_lookup_idx
  on public.erp_inventory_movements(company_id, warehouse_id, item_id, movement_date);
create index if not exists erp_stock_expiry_idx
  on public.erp_inventory_movements(item_id, expiry_date)
  where expiry_date is not null;

alter table public.erp_purchase_documents enable row level security;
alter table public.erp_purchase_lines enable row level security;
alter table public.erp_sales_documents enable row level security;
alter table public.erp_sales_lines enable row level security;
alter table public.erp_inventory_movements enable row level security;

drop trigger if exists erp_purchase_documents_updated_at on public.erp_purchase_documents;
create trigger erp_purchase_documents_updated_at before update on public.erp_purchase_documents
for each row execute function public.erp_set_updated_at();
drop trigger if exists erp_sales_documents_updated_at on public.erp_sales_documents;
create trigger erp_sales_documents_updated_at before update on public.erp_sales_documents
for each row execute function public.erp_set_updated_at();

-- Stock is calculated from posted movements; this view deliberately does not
-- create mutable cached balances, avoiding double updates from retries.
create or replace view public.erp_stock_balances as
select
  company_id,
  branch_id,
  warehouse_id,
  item_id,
  sum(quantity_in - quantity_out) as quantity_on_hand
from public.erp_inventory_movements
group by company_id, branch_id, warehouse_id, item_id;
