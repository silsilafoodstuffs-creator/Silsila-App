-- ERP administrators maintain the shared activity dictionary.
CREATE POLICY activity_types_erp_admin_insert ON public.activity_types
FOR INSERT TO authenticated
WITH CHECK (EXISTS (SELECT 1 FROM public.erp_company_members m WHERE m.user_id = (SELECT auth.uid()) AND m.is_active = true AND m.member_role IN ('owner','admin')));
CREATE POLICY activity_types_erp_admin_update ON public.activity_types
FOR UPDATE TO authenticated
USING (EXISTS (SELECT 1 FROM public.erp_company_members m WHERE m.user_id = (SELECT auth.uid()) AND m.is_active = true AND m.member_role IN ('owner','admin')))
WITH CHECK (EXISTS (SELECT 1 FROM public.erp_company_members m WHERE m.user_id = (SELECT auth.uid()) AND m.is_active = true AND m.member_role IN ('owner','admin')));
CREATE POLICY activity_types_erp_admin_delete ON public.activity_types
FOR DELETE TO authenticated
USING (EXISTS (SELECT 1 FROM public.erp_company_members m WHERE m.user_id = (SELECT auth.uid()) AND m.is_active = true AND m.member_role IN ('owner','admin')));
CREATE POLICY activity_types_erp_admin_read ON public.activity_types
FOR SELECT TO authenticated
USING (EXISTS (SELECT 1 FROM public.erp_company_members m WHERE m.user_id = (SELECT auth.uid()) AND m.is_active = true AND m.member_role IN ('owner','admin')));