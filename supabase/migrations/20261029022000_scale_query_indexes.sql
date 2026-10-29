-- Query-pattern indexes for tenant-scoped searches and large chronological ledgers.
-- Trigram indexes accelerate contains-search (ILIKE '%term%') on catalog/master data.
create extension if not exists pg_trgm with schema extensions;
create index if not exists erp_items_company_active_name_idx on public.erp_items(company_id, is_active, item_name);
create index if not exists erp_items_name_trgm_idx on public.erp_items using gin (item_name extensions.gin_trgm_ops);
create index if not exists erp_items_code_trgm_idx on public.erp_items using gin (item_code extensions.gin_trgm_ops);
create index if not exists erp_items_barcode_trgm_idx on public.erp_items using gin (barcode extensions.gin_trgm_ops) where barcode is not null;
create index if not exists erp_parties_company_active_name_idx on public.erp_parties(company_id, is_active, party_name);
create index if not exists erp_parties_name_trgm_idx on public.erp_parties using gin (party_name extensions.gin_trgm_ops);
create index if not exists erp_parties_code_trgm_idx on public.erp_parties using gin (party_code extensions.gin_trgm_ops);
create index if not exists erp_sales_documents_company_status_date_idx on public.erp_sales_documents(company_id, status, document_date desc);
create index if not exists erp_purchase_documents_company_status_date_idx on public.erp_purchase_documents(company_id, status, document_date desc);
create index if not exists erp_inventory_movements_company_item_date_idx on public.erp_inventory_movements(company_id, item_id, movement_date desc);
create index if not exists erp_inventory_movements_company_warehouse_date_idx on public.erp_inventory_movements(company_id, warehouse_id, movement_date desc);
create index if not exists erp_workspace_records_company_page_created_idx on public.erp_workspace_records(company_id, page_key, created_at desc);