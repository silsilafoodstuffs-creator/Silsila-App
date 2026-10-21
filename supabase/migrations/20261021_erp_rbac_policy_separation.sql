-- Read policies are separate from write policies; ERP tables are never public-read.
drop policy if exists erp_operational_account_mappings_write_accounting on public.erp_operational_account_mappings;
drop policy if exists erp_operational_account_mappings_insert_accounting on public.erp_operational_account_mappings;
create policy erp_operational_account_mappings_insert_accounting on public.erp_operational_account_mappings for insert to authenticated
with check (public.erp_user_has_company_role(company_id,array['owner','admin','accountant']::text[]));
drop policy if exists erp_operational_account_mappings_update_accounting on public.erp_operational_account_mappings;
create policy erp_operational_account_mappings_update_accounting on public.erp_operational_account_mappings for update to authenticated
using (public.erp_user_has_company_role(company_id,array['owner','admin','accountant']::text[]))
with check (public.erp_user_has_company_role(company_id,array['owner','admin','accountant']::text[]));
drop policy if exists erp_operational_account_mappings_delete_accounting on public.erp_operational_account_mappings;
create policy erp_operational_account_mappings_delete_accounting on public.erp_operational_account_mappings for delete to authenticated
using (public.erp_user_has_company_role(company_id,array['owner','admin','accountant']::text[]));

drop policy if exists erp_user_branch_warehouse_access_select on public.erp_user_branch_warehouse_access;
create policy erp_user_branch_warehouse_access_select on public.erp_user_branch_warehouse_access for select to authenticated
using (public.erp_user_can_access_company(company_id));
drop policy if exists erp_user_branch_warehouse_access_write on public.erp_user_branch_warehouse_access;
drop policy if exists erp_user_branch_warehouse_access_insert on public.erp_user_branch_warehouse_access;
create policy erp_user_branch_warehouse_access_insert on public.erp_user_branch_warehouse_access for insert to authenticated
with check (public.erp_user_has_company_role(company_id,array['owner','admin','manager']::text[]));
drop policy if exists erp_user_branch_warehouse_access_update on public.erp_user_branch_warehouse_access;
create policy erp_user_branch_warehouse_access_update on public.erp_user_branch_warehouse_access for update to authenticated
using (public.erp_user_has_company_role(company_id,array['owner','admin','manager']::text[]))
with check (public.erp_user_has_company_role(company_id,array['owner','admin','manager']::text[]));
drop policy if exists erp_user_branch_warehouse_access_delete on public.erp_user_branch_warehouse_access;
create policy erp_user_branch_warehouse_access_delete on public.erp_user_branch_warehouse_access for delete to authenticated
using (public.erp_user_has_company_role(company_id,array['owner','admin','manager']::text[]));

drop policy if exists erp_user_classifications_select on public.erp_user_classifications;
create policy erp_user_classifications_select on public.erp_user_classifications for select to authenticated
using (public.erp_user_can_access_company(company_id));
drop policy if exists erp_user_classifications_write on public.erp_user_classifications;
drop policy if exists erp_user_classifications_insert on public.erp_user_classifications;
create policy erp_user_classifications_insert on public.erp_user_classifications for insert to authenticated
with check (public.erp_user_has_company_role(company_id,array['owner','admin','manager']::text[]));
drop policy if exists erp_user_classifications_update on public.erp_user_classifications;
create policy erp_user_classifications_update on public.erp_user_classifications for update to authenticated
using (public.erp_user_has_company_role(company_id,array['owner','admin','manager']::text[]))
with check (public.erp_user_has_company_role(company_id,array['owner','admin','manager']::text[]));
drop policy if exists erp_user_classifications_delete on public.erp_user_classifications;
create policy erp_user_classifications_delete on public.erp_user_classifications for delete to authenticated
using (public.erp_user_has_company_role(company_id,array['owner','admin','manager']::text[]));
