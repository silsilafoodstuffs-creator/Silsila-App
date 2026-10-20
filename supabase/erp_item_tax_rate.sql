-- Add a default VAT/tax percentage to the ERP item card.
-- Apply after erp_schema.sql. Existing items default to 0% until configured.
alter table public.erp_items
  add column if not exists tax_rate numeric(7,4) not null default 0
  check (tax_rate >= 0 and tax_rate <= 100);

comment on column public.erp_items.tax_rate is
  'Default item tax percentage used on tax invoices; non-tax invoices ignore it.';
