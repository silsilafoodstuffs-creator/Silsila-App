-- Fail-closed company-scoped RLS for ERP operational tables.
-- Access is limited to active company owners/admins until the fine-grained
-- permission matrix is enforced server-side on every operational write.
begin;
drop policy if exists erp_item_units_company_admin_all on public.erp_item_units;
drop policy if exists erp_party_contacts_company_admin_all on public.erp_party_contacts;
drop policy if exists erp_party_price_lists_company_admin_all on public.erp_party_price_lists;
drop policy if exists erp_price_lists_company_admin_all on public.erp_price_lists;
drop policy if exists erp_price_list_lines_company_admin_all on public.erp_price_list_lines;
drop policy if exists erp_purchase_documents_company_admin_all on public.erp_purchase_documents;
drop policy if exists erp_purchase_lines_company_admin_all on public.erp_purchase_lines;
drop policy if exists erp_sales_documents_company_admin_all on public.erp_sales_documents;
drop policy if exists erp_sales_lines_company_admin_all on public.erp_sales_lines;
create policy erp_item_units_company_admin_all on public.erp_item_units for all to authenticated using (public.erp_user_has_company_role(company_id, array['owner','admin']::text[])) with check (public.erp_user_has_company_role(company_id, array['owner','admin']::text[]));
create policy erp_party_contacts_company_admin_all on public.erp_party_contacts for all to authenticated using (public.erp_user_has_company_role(company_id, array['owner','admin']::text[])) with check (public.erp_user_has_company_role(company_id, array['owner','admin']::text[]));
create policy erp_party_price_lists_company_admin_all on public.erp_party_price_lists for all to authenticated using (public.erp_user_has_company_role(company_id, array['owner','admin']::text[])) with check (public.erp_user_has_company_role(company_id, array['owner','admin']::text[]));
create policy erp_price_lists_company_admin_all on public.erp_price_lists for all to authenticated using (public.erp_user_has_company_role(company_id, array['owner','admin']::text[])) with check (public.erp_user_has_company_role(company_id, array['owner','admin']::text[]));
create policy erp_price_list_lines_company_admin_all on public.erp_price_list_lines for all to authenticated using (public.erp_user_has_company_role(company_id, array['owner','admin']::text[])) with check (public.erp_user_has_company_role(company_id, array['owner','admin']::text[]));
create policy erp_purchase_documents_company_admin_all on public.erp_purchase_documents for all to authenticated using (public.erp_user_has_company_role(company_id, array['owner','admin']::text[])) with check (public.erp_user_has_company_role(company_id, array['owner','admin']::text[]));
create policy erp_purchase_lines_company_admin_all on public.erp_purchase_lines for all to authenticated using (exists(select 1 from public.erp_purchase_documents d where d.id=document_id and public.erp_user_has_company_role(d.company_id, array['owner','admin']::text[]))) with check (exists(select 1 from public.erp_purchase_documents d where d.id=document_id and public.erp_user_has_company_role(d.company_id, array['owner','admin']::text[])));
create policy erp_sales_documents_company_admin_all on public.erp_sales_documents for all to authenticated using (public.erp_user_has_company_role(company_id, array['owner','admin']::text[])) with check (public.erp_user_has_company_role(company_id, array['owner','admin']::text[]));
create policy erp_sales_lines_company_admin_all on public.erp_sales_lines for all to authenticated using (exists(select 1 from public.erp_sales_documents d where d.id=document_id and public.erp_user_has_company_role(d.company_id, array['owner','admin']::text[]))) with check (exists(select 1 from public.erp_sales_documents d where d.id=document_id and public.erp_user_has_company_role(d.company_id, array['owner','admin']::text[])));
create index if not exists erp_item_units_item_idx on public.erp_item_units(item_id);
create index if not exists erp_party_contacts_party_idx on public.erp_party_contacts(party_id);
create index if not exists erp_party_price_lists_party_idx on public.erp_party_price_lists(party_id);
create index if not exists erp_party_price_lists_price_list_idx on public.erp_party_price_lists(price_list_id);
create index if not exists erp_price_list_lines_price_list_idx on public.erp_price_list_lines(price_list_id);
create index if not exists erp_price_list_lines_item_idx on public.erp_price_list_lines(item_id);
create index if not exists erp_price_list_lines_unit_idx on public.erp_price_list_lines(item_unit_id);
create index if not exists erp_purchase_documents_branch_idx on public.erp_purchase_documents(branch_id);
create index if not exists erp_purchase_documents_warehouse_idx on public.erp_purchase_documents(warehouse_id);
create index if not exists erp_purchase_documents_supplier_idx on public.erp_purchase_documents(supplier_id);
create index if not exists erp_purchase_lines_item_idx on public.erp_purchase_lines(item_id);
create index if not exists erp_sales_documents_branch_idx on public.erp_sales_documents(branch_id);
create index if not exists erp_sales_documents_warehouse_idx on public.erp_sales_documents(warehouse_id);
create index if not exists erp_sales_documents_customer_idx on public.erp_sales_documents(customer_id);
create index if not exists erp_sales_lines_item_idx on public.erp_sales_lines(item_id);
commit;
