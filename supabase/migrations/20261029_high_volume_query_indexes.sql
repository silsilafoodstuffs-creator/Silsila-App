-- Performance indexes for high-volume tenant-scoped ERP queries.
-- Apply only after the core ERP schema and operational schema are installed.
-- These indexes do not change business data or accounting behavior.

begin;

create index if not exists erp_items_company_active_name_idx
  on public.erp_items (company_id, is_active, item_name);

create index if not exists erp_items_company_barcode_idx
  on public.erp_items (company_id, barcode)
  where barcode is not null and length(trim(barcode)) > 0;

create index if not exists erp_parties_company_active_name_idx
  on public.erp_parties (company_id, is_active, party_name);

create index if not exists erp_sales_documents_company_status_date_idx
  on public.erp_sales_documents (company_id, status, document_date desc);

create index if not exists erp_purchase_documents_company_status_date_idx
  on public.erp_purchase_documents (company_id, status, document_date desc);

create index if not exists erp_sales_lines_document_idx
  on public.erp_sales_lines (document_id, created_at);

create index if not exists erp_purchase_lines_document_idx
  on public.erp_purchase_lines (document_id, created_at);

create index if not exists erp_inventory_movements_company_item_date_idx
  on public.erp_inventory_movements (company_id, item_id, movement_date desc);

create index if not exists erp_inventory_movements_company_warehouse_date_idx
  on public.erp_inventory_movements (company_id, warehouse_id, movement_date desc);

commit;
