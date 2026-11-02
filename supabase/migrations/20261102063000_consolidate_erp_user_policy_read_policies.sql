-- Preserve the existing company-member read path while also allowing an
-- active ERP user to read their own identity and company duration policies.
-- Fold the additional checks into the existing SELECT policies to avoid
-- multiplying permissive RLS policies.

drop policy if exists erp_users_read_self on public.erp_users;
drop policy if exists erp_users_member_read on public.erp_users;
create policy erp_users_member_read
on public.erp_users
for select
to authenticated
using (
  (auth_user_id = (select auth.uid()) and is_active = true)
  or erp_user_can_access_company(company_id)
);

drop policy if exists erp_program_policies_company_user_read on public.erp_program_policies;
drop policy if exists erp_program_policies_member_read on public.erp_program_policies;
create policy erp_program_policies_member_read
on public.erp_program_policies
for select
to authenticated
using (private.can_read_erp_company_policies(company_id));
