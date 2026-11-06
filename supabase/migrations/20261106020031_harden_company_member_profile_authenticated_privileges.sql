-- Keep company-member profile CRUD for signed-in app users while removing
-- unnecessary table-level powers that the client application never uses.
REVOKE ALL PRIVILEGES ON TABLE public.erp_company_member_profiles FROM authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON TABLE public.erp_company_member_profiles TO authenticated;
