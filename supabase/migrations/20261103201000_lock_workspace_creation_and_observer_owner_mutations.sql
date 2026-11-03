create or replace function private.is_business_workspace_owner(p_workspace_id uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $function$
  select
    not private.is_silsila_workspace_observer()
    and exists(
      select 1 from public.erp_business_workspaces w
      where w.id=p_workspace_id
        and w.owner_user_id=(select auth.uid())
        and w.is_active
    )
$function$;

drop policy if exists business_workspace_insert on public.erp_business_workspaces;
drop policy if exists business_workspace_update on public.erp_business_workspaces;
create policy business_workspace_update
on public.erp_business_workspaces
for update to authenticated
using (
  owner_user_id=(select auth.uid())
  and not private.is_silsila_workspace_observer()
)
with check (
  owner_user_id=(select auth.uid())
  and not private.is_silsila_workspace_observer()
);

revoke all on public.erp_business_workspaces from anon, authenticated;
grant select, update on public.erp_business_workspaces to authenticated;
