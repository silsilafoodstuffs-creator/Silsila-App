create or replace function private.can_access_business_workspace(
  p_workspace_id uuid,
  p_permission text default 'workspace.enter'
)
returns boolean
language sql
stable
security definer
set search_path = ''
as $function$
  select case
    when private.is_silsila_workspace_observer() then
      p_permission = any(array[
        'workspace.enter','master.read','items.read','inventory.read',
        'purchases.read','sales.read','cash.read','hr.read','reports.read',
        'members.read','audit.read','customers.read','suppliers.read'
      ]::text[])
      and exists (
        select 1 from public.erp_business_workspaces w
        where w.id=p_workspace_id and w.is_active
      )
    else
      exists (
        select 1
        from public.erp_business_workspaces w
        where w.id=p_workspace_id and w.is_active
          and (
            w.owner_user_id=(select auth.uid())
            or exists (
              select 1
              from public.erp_business_workspace_members m
              where m.workspace_id=w.id
                and m.user_id=(select auth.uid())
                and m.is_active
                and m.can_open_workspace
                and (
                  m.member_role in ('owner','admin')
                  or m.permissions->>p_permission='true'
                  or m.permissions->>'*'='true'
                  or (p_permission like '%.read'
                      and m.permissions->>replace(p_permission,'.read','.manage')='true')
                )
            )
          )
      )
  end;
$function$;
grant execute on function private.can_access_business_workspace(uuid,text) to authenticated;
