-- Company-wide master records may have no branch. Keep existing
-- permissive role/company policies as the authorization boundary, and only
-- apply branch-scope checks to records explicitly assigned to a branch.

drop policy if exists erp_scope_guard_erp_cashboxes on public.erp_cashboxes;
create policy erp_scope_guard_erp_cashboxes
on public.erp_cashboxes
as restrictive
for all
to authenticated
using (
  branch_id is null
  or public.erp_user_can_access_branch_scope(company_id, branch_id)
)
with check (
  branch_id is null
  or public.erp_user_can_access_branch_scope(company_id, branch_id)
);

drop policy if exists erp_scope_guard_erp_employees on public.erp_employees;
create policy erp_scope_guard_erp_employees
on public.erp_employees
as restrictive
for all
to authenticated
using (
  (branch_id is null and public.erp_user_can_access_company(company_id))
  or public.erp_user_can_access_branch_scope(company_id, branch_id)
)
with check (
  (branch_id is null and public.erp_user_can_access_company(company_id))
  or public.erp_user_can_access_branch_scope(company_id, branch_id)
);
