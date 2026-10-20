-- Sales invoice header fields used by the Silsila ERP invoice screen.
-- Prerequisites: erp_operations_schema.sql and erp_sales_goals_commissions_demo_data.sql.
-- Safe to re-run; existing documents remain non-tax invoices by default.
alter table public.erp_sales_documents
  add column if not exists is_tax_invoice boolean not null default false;

alter table public.erp_sales_documents
  add column if not exists sales_rep_id uuid
  references public.erp_sales_representatives(id) on delete set null;

create index if not exists erp_sales_documents_sales_rep_idx
  on public.erp_sales_documents(company_id, sales_rep_id, document_date);

comment on column public.erp_sales_documents.is_tax_invoice is
  'Whether the sales document is treated as a tax invoice; defaults to false.';
comment on column public.erp_sales_documents.sales_rep_id is
  'Sales representative assigned to the customer/document.';
