-- Sales source tracking and separate preparation/delivery notes.
-- Apply after erp_operations_schema.sql and membership/RLS setup.
alter table public.erp_sales_documents
  add column if not exists source_channel text not null default 'manual'
  check (source_channel in ('app','manual','crm','documents'));
alter table public.erp_sales_documents
  add column if not exists source_document_ids uuid[] not null default '{}'::uuid[];
comment on column public.erp_sales_documents.source_channel is
  'Origin of the sales document: app, manual, CRM, or linked source documents.';
comment on column public.erp_sales_documents.source_document_ids is
  'One or more source sales document IDs (orders for invoices, quotations for orders).';

create table if not exists public.erp_sales_fulfillment_documents (
  id uuid primary key default gen_random_uuid(),
  company_id uuid not null references public.erp_companies(id) on delete restrict,
  kind text not null check (kind in ('preparation','delivery')),
  invoice_id uuid not null references public.erp_sales_documents(id) on delete restrict,
  source_fulfillment_ids uuid[] not null default '{}'::uuid[],
  source_mode text not null default 'invoice'
    check (source_mode in ('invoice','preparation','direct')),
  manual_number text not null,
  customer_name text not null default '',
  area_name text not null default '',
  invoice_amount numeric(14,2) not null default 0 check (invoice_amount >= 0),
  weight_kg numeric(14,3) not null default 0 check (weight_kg >= 0),
  load_kg numeric(14,3) not null default 0 check (load_kg >= 0),
  status text not null default 'draft'
    check (status in ('draft','completed','cancelled')),
  notes text,
  created_by uuid references auth.users(id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (company_id, kind, manual_number),
  unique (company_id, kind, invoice_id)
);

create index if not exists erp_sales_fulfillment_invoice_idx
  on public.erp_sales_fulfillment_documents(company_id, invoice_id, kind, status);
create index if not exists erp_sales_fulfillment_kind_idx
  on public.erp_sales_fulfillment_documents(company_id, kind, created_at desc);

alter table public.erp_sales_fulfillment_documents enable row level security;
drop trigger if exists erp_sales_fulfillment_updated_at on public.erp_sales_fulfillment_documents;
create trigger erp_sales_fulfillment_updated_at
before update on public.erp_sales_fulfillment_documents
for each row execute function public.erp_set_updated_at();

-- Access is limited to active members of the owning company.
drop policy if exists erp_sales_fulfillment_member_select on public.erp_sales_fulfillment_documents;
create policy erp_sales_fulfillment_member_select
on public.erp_sales_fulfillment_documents for select to authenticated
using (exists (
  select 1 from public.erp_company_members m
  where m.company_id = erp_sales_fulfillment_documents.company_id
    and m.user_id = auth.uid() and m.is_active = true
));
drop policy if exists erp_sales_fulfillment_member_insert on public.erp_sales_fulfillment_documents;
create policy erp_sales_fulfillment_member_insert
on public.erp_sales_fulfillment_documents for insert to authenticated
with check (exists (
  select 1 from public.erp_company_members m
  where m.company_id = erp_sales_fulfillment_documents.company_id
    and m.user_id = auth.uid() and m.is_active = true
));
drop policy if exists erp_sales_fulfillment_member_update on public.erp_sales_fulfillment_documents;
create policy erp_sales_fulfillment_member_update
on public.erp_sales_fulfillment_documents for update to authenticated
using (exists (
  select 1 from public.erp_company_members m
  where m.company_id = erp_sales_fulfillment_documents.company_id
    and m.user_id = auth.uid() and m.is_active = true
))
with check (exists (
  select 1 from public.erp_company_members m
  where m.company_id = erp_sales_fulfillment_documents.company_id
    and m.user_id = auth.uid() and m.is_active = true
));
