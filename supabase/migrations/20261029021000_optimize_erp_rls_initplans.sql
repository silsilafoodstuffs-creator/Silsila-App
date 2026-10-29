alter policy erp_data_backups_insert_admin on public.erp_data_backups
with check (erp_user_has_company_role(company_id, ARRAY['owner'::text, 'admin'::text]) AND ((created_by IS NULL) OR (created_by = (select auth.uid()))));

alter policy erp_program_policies_manager_write on public.erp_program_policies
using (exists (select 1 from public.erp_company_members m where m.company_id = erp_program_policies.company_id and m.user_id = (select auth.uid()) and m.is_active = true and lower(m.member_role) = any (ARRAY['owner'::text, 'مالك'::text, 'admin'::text, 'ادمن'::text, 'مدير النظام'::text, 'مدير'::text])))
with check (exists (select 1 from public.erp_company_members m where m.company_id = erp_program_policies.company_id and m.user_id = (select auth.uid()) and m.is_active = true and lower(m.member_role) = any (ARRAY['owner'::text, 'مالك'::text, 'admin'::text, 'ادمن'::text, 'مدير النظام'::text, 'مدير'::text])));

alter policy erp_program_policies_member_read on public.erp_program_policies
using (exists (select 1 from public.erp_company_members m where m.company_id = erp_program_policies.company_id and m.user_id = (select auth.uid()) and m.is_active = true));

alter policy erp_program_settings_member_insert on public.erp_program_settings
with check (exists (select 1 from public.erp_company_members m where m.company_id = erp_program_settings.company_id and m.user_id = (select auth.uid()) and m.is_active = true));

alter policy erp_program_settings_member_select on public.erp_program_settings
using (exists (select 1 from public.erp_company_members m where m.company_id = erp_program_settings.company_id and m.user_id = (select auth.uid()) and m.is_active = true));

alter policy erp_program_settings_member_update on public.erp_program_settings
using (exists (select 1 from public.erp_company_members m where m.company_id = erp_program_settings.company_id and m.user_id = (select auth.uid()) and m.is_active = true))
with check (exists (select 1 from public.erp_company_members m where m.company_id = erp_program_settings.company_id and m.user_id = (select auth.uid()) and m.is_active = true));

alter policy erp_sales_invoice_audit_member_read on public.erp_sales_invoice_audit_log
using (exists (select 1 from public.erp_company_members m where m.company_id = erp_sales_invoice_audit_log.company_id and m.user_id = (select auth.uid()) and m.is_active = true));

alter policy erp_supplier_deferred_commissions_manager_write on public.erp_supplier_deferred_commissions
using (exists (select 1 from public.erp_company_members m where m.company_id = erp_supplier_deferred_commissions.company_id and m.user_id = (select auth.uid()) and m.is_active = true and lower(m.member_role) = any (ARRAY['owner'::text, 'مالك'::text, 'admin'::text, 'ادمن'::text, 'مدير النظام'::text, 'مدير'::text])))
with check (exists (select 1 from public.erp_company_members m where m.company_id = erp_supplier_deferred_commissions.company_id and m.user_id = (select auth.uid()) and m.is_active = true and lower(m.member_role) = any (ARRAY['owner'::text, 'مالك'::text, 'admin'::text, 'ادمن'::text, 'مدير النظام'::text, 'مدير'::text])));

alter policy erp_supplier_deferred_commissions_member_read on public.erp_supplier_deferred_commissions
using (exists (select 1 from public.erp_company_members m where m.company_id = erp_supplier_deferred_commissions.company_id and m.user_id = (select auth.uid()) and m.is_active = true));