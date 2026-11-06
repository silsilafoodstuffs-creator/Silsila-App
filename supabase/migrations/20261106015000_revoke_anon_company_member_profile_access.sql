-- Company-member profile records are private to authenticated company members.
-- Anonymous clients have no matching RLS policy and do not need table-level access.
REVOKE ALL PRIVILEGES ON TABLE public.erp_company_member_profiles FROM anon;
