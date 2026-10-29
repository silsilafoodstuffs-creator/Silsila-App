-- Additional indexes for frequently accessed master-data and workspace queries.
-- Run each statement outside an explicit transaction (CONCURRENTLY requirement).
-- Apply only after confirming the corresponding tables exist in this database.

create index concurrently if not exists erp_workspace_records_company_page_created_idx
  on public.erp_workspace_records (company_id, page_key, created_at desc);

create index concurrently if not exists erp_stock_balances_company_warehouse_item_idx
  on public.erp_stock_balances (company_id, warehouse_id, item_id);

create index concurrently if not exists erp_item_units_company_active_item_idx
  on public.erp_item_units (company_id, is_active, item_id);

create index concurrently if not exists erp_price_list_lines_company_list_item_idx
  on public.erp_price_list_lines (company_id, price_list_id, item_id);

create index concurrently if not exists erp_party_warehouses_company_party_idx
  on public.erp_party_warehouses (company_id, party_id, warehouse_id);
