-- Allow company-wide cost centers (branch_id IS NULL) while preserving
-- branch-level row scoping for centers assigned to a specific branch.
-- Company-wide master data must remain visible to authorized company members.
drop policy if exists erp_scope_guard_erp_cost_centers on public.erp_cost_centers;

create policy erp_scope_guard_erp_cost_centers
on public.erp_cost_centers
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
