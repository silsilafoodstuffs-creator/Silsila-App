-- Idempotent indexes for ERP foreign-key lookup paths.
-- These indexes support company members, cost-center trees, inventory movements,
-- operational accounting mappings, and sales/purchase document line lookups.
create index if not exists erp_company_member_profiles_branch_idx on public.erp_company_member_profiles(branch_id);
create index if not exists erp_company_member_profiles_updated_by_idx on public.erp_company_member_profiles(updated_by);
create index if not exists erp_company_member_profiles_user_idx on public.erp_company_member_profiles(user_id);
create index if not exists erp_cost_centers_branch_idx on public.erp_cost_centers(branch_id);
create index if not exists erp_cost_centers_parent_idx on public.erp_cost_centers(parent_id);
create index if not exists erp_inventory_movements_branch_idx on public.erp_inventory_movements(branch_id);
create index if not exists erp_inventory_movements_created_by_idx on public.erp_inventory_movements(created_by);
create index if not exists erp_inventory_movements_warehouse_idx on public.erp_inventory_movements(warehouse_id);
create index if not exists erp_operational_account_mappings_ar_idx on public.erp_operational_account_mappings(accounts_receivable_account_id);
create index if not exists erp_operational_account_mappings_ap_idx on public.erp_operational_account_mappings(accounts_payable_account_id);
create index if not exists erp_operational_account_mappings_sales_revenue_idx on public.erp_operational_account_mappings(sales_revenue_account_id);
create index if not exists erp_operational_account_mappings_sales_returns_idx on public.erp_operational_account_mappings(sales_returns_account_id);
create index if not exists erp_operational_account_mappings_inventory_idx on public.erp_operational_account_mappings(inventory_account_id);
create index if not exists erp_operational_account_mappings_cogs_idx on public.erp_operational_account_mappings(cost_of_goods_sold_account_id);
create index if not exists erp_operational_account_mappings_sales_tax_idx on public.erp_operational_account_mappings(sales_tax_payable_account_id);
create index if not exists erp_operational_account_mappings_purchase_tax_idx on public.erp_operational_account_mappings(purchase_tax_credit_account_id);
create index if not exists erp_operational_account_mappings_return_variance_idx on public.erp_operational_account_mappings(purchase_return_variance_account_id);
create index if not exists erp_operational_account_mappings_created_by_idx on public.erp_operational_account_mappings(created_by);
create index if not exists erp_purchase_documents_created_by_idx on public.erp_purchase_documents(created_by);
create index if not exists erp_purchase_lines_document_idx on public.erp_purchase_lines(document_id);
create index if not exists erp_sales_documents_created_by_idx on public.erp_sales_documents(created_by);
create index if not exists erp_sales_lines_document_idx on public.erp_sales_lines(document_id);
create index if not exists erp_user_permissions_updated_by_idx on public.erp_user_permissions(updated_by);
create index if not exists erp_user_permissions_user_idx on public.erp_user_permissions(user_id);
