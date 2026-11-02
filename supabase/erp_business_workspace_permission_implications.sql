create or replace function private.can_access_business_workspace(
 p_workspace_id uuid,p_permission text default 'workspace.enter'
) returns boolean language sql stable security definer
set search_path=pg_catalog,public,auth,private
as $$
 select exists(
  select 1 from public.erp_business_workspaces w
  where w.id=p_workspace_id and w.is_active
   and (
    w.owner_user_id=(select auth.uid())
    or exists(
     select 1 from public.erp_business_workspace_members m
     where m.workspace_id=w.id and m.user_id=(select auth.uid()) and m.is_active and m.can_open_workspace
      and (
       m.member_role in ('owner','admin')
       or coalesce((m.permissions->>p_permission)::boolean,false)
       or coalesce((m.permissions->>'*')::boolean,false)
       or (p_permission like '%.read' and coalesce((m.permissions->>replace(p_permission,'.read','.manage'))::boolean,false))
      )
    )
   )
 )
$$;
revoke all on function private.can_access_business_workspace(uuid,text) from public,anon;
grant execute on function private.can_access_business_workspace(uuid,text) to authenticated;
