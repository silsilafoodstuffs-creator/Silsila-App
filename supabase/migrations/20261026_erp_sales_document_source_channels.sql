begin;
alter table public.erp_sales_documents
  drop constraint if exists erp_sales_documents_source_channel_check;
alter table public.erp_sales_documents
  add constraint erp_sales_documents_source_channel_check
  check (source_channel in ('app','manual','crm','documents','kartona','follow_up'));
comment on column public.erp_sales_documents.source_channel is
  'Origin channel: Silsila app, manual entry, CRM, Kartona app, follow-up department, or linked source document.';
commit;
