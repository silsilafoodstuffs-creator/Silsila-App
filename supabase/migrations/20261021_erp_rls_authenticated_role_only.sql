-- ERP write policies must apply only to authenticated sessions.
-- The same role checks remain in place; anonymous requests are rejected before policy evaluation.
alter policy erp_party_warehouses_delete_admin on public.erp_party_warehouses to authenticated;
alter policy erp_party_warehouses_insert_operator on public.erp_party_warehouses to authenticated;
alter policy erp_party_warehouses_update_operator on public.erp_party_warehouses to authenticated;
alter policy erp_user_branch_warehouse_access_write on public.erp_user_branch_warehouse_access to authenticated;
alter policy erp_user_classifications_write on public.erp_user_classifications to authenticated;
