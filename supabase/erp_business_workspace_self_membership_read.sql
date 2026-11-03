-- A member must be able to read their own permission row even when
-- they are not granted members.read. Otherwise client-side navigation
-- cannot evaluate their assigned module permissions.
drop policy if exists workspace_select on public.erp_business_workspace_members;
create policy workspace_select
on public.erp_business_workspace_members
for select
to authenticated
using (
  user_id = (select auth.uid())
  or private.can_access_business_workspace(workspace_id,'members.read')
);
