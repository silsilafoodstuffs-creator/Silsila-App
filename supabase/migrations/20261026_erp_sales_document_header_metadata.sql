-- Sales document header metadata: fiscal period and payment terms.
begin;

alter table public.erp_sales_documents
  add column if not exists fiscal_year text,
  add column if not exists fiscal_period_id uuid references public.erp_fiscal_periods(id) on delete restrict,
  add column if not exists payment_type text not null default 'آجل';

update public.erp_sales_documents
set fiscal_year = coalesce(nullif(btrim(fiscal_year), ''), extract(year from document_date)::integer::text)
where fiscal_year is null or btrim(fiscal_year) = '';

alter table public.erp_sales_documents
  alter column fiscal_year set default to_char(current_date, 'YYYY'),
  alter column fiscal_year set not null;

alter table public.erp_sales_documents
  drop constraint if exists erp_sales_documents_payment_type_check;
alter table public.erp_sales_documents
  add constraint erp_sales_documents_payment_type_check
  check (payment_type in ('نقدي','آجل','بيع مباشر'));

create index if not exists erp_sales_documents_fiscal_period_idx
  on public.erp_sales_documents(company_id, fiscal_period_id, document_date);

comment on column public.erp_sales_documents.fiscal_year is 'Financial year/period label displayed in the sales document header.';
comment on column public.erp_sales_documents.payment_type is 'Sales settlement type: cash, credit, or direct sale.';
comment on column public.erp_sales_documents.document_number is 'Manual document serial; unique per company by the existing unique constraint.';

commit;
