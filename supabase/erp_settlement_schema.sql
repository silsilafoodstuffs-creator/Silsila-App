-- Silsila ERP receipts and payments register.
-- Apply after erp_schema.sql and erp_operations_schema.sql.
-- This schema stores settlement documents only; it does not itself update balances,
-- post journal entries, or allocate payments to invoices.
-- RLS is enabled with no permissive policies until tenant/branch policies are added.

create table if not exists public.erp_settlements (
  id uuid primary key default gen_random_uuid(),
  company_id uuid not null references public.erp_companies(id) on delete restrict,
  branch_id uuid references public.erp_branches(id) on delete restrict,
  party_id uuid not null references public.erp_parties(id) on delete restrict,
  cashbox_id uuid not null references public.erp_cashboxes(id) on delete restrict,
  settlement_number text not null,
  settlement_date date not null default current_date,
  settlement_kind text not null check (settlement_kind in (
    'customer_receipt','supplier_payment','customer_refund','supplier_refund','other_receipt','other_payment'
  )),
  payment_method text not null default 'cash' check (payment_method in (
    'cash','bank_transfer','cheque','wallet','card','other'
  )),
  status text not null default 'draft' check (status in ('draft','approved','posted','cancelled')),
  amount numeric(14,2) not null check (amount > 0),
  external_reference text,
  notes text,
  created_by uuid references auth.users(id) on delete set null,
  approved_by uuid references auth.users(id) on delete set null,
  approved_at timestamptz,
  posted_by uuid references auth.users(id) on delete set null,
  posted_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (company_id, settlement_number)
);

create table if not exists public.erp_settlement_allocations (
  id uuid primary key default gen_random_uuid(),
  settlement_id uuid not null references public.erp_settlements(id) on delete cascade,
  document_kind text not null check (document_kind in ('purchase','sale')),
  document_id uuid not null,
  allocated_amount numeric(14,2) not null check (allocated_amount > 0),
  notes text,
  created_at timestamptz not null default now(),
  unique (settlement_id, document_kind, document_id)
);

create index if not exists erp_settlements_party_date_idx
  on public.erp_settlements(company_id, party_id, settlement_date desc);
create index if not exists erp_settlements_cashbox_date_idx
  on public.erp_settlements(company_id, cashbox_id, settlement_date desc);
create index if not exists erp_settlements_status_idx
  on public.erp_settlements(company_id, status, settlement_date desc);
create index if not exists erp_settlement_allocations_document_idx
  on public.erp_settlement_allocations(document_kind, document_id);

alter table public.erp_settlements enable row level security;
alter table public.erp_settlement_allocations enable row level security;

drop trigger if exists erp_settlements_updated_at on public.erp_settlements;
create trigger erp_settlements_updated_at before update on public.erp_settlements
for each row execute function public.erp_set_updated_at();

-- Production backend requirements:
-- * Verify party, cashbox, company and branch belong to the same authorized tenant.
-- * Verify the settlement kind is compatible with the party kind and document kind.
-- * Enforce total allocations <= settlement amount and <= the target document's open balance.
-- * Approve/post atomically; create balanced journal entries exactly once; reject reposting.
-- * Prevent editing/deleting posted documents and expose only tenant-scoped RLS policies.
-- * Keep bank/wallet references non-sensitive; never store full card or bank credentials.
