create or replace function private.can_access_business_workspace_location(
 p_workspace_id uuid,p_branch_id uuid default null,p_warehouse_id uuid default null
) returns boolean
language plpgsql stable security definer
set search_path=pg_catalog,public,auth,private
as $$
declare
 v_user uuid:=(select auth.uid());
 v_branch uuid:=p_branch_id;
 v_has_rules boolean;
 v_has_allow_rules boolean;
 v_has_allowed_warehouse boolean;
begin
 if v_user is null then return false; end if;
 if exists(select 1 from public.erp_business_workspaces w where w.id=p_workspace_id and w.owner_user_id=v_user and w.is_active) then return true; end if;
 if not exists(select 1 from public.erp_business_workspace_members m where m.workspace_id=p_workspace_id and m.user_id=v_user and m.is_active and m.can_open_workspace) then return false; end if;
 if p_branch_id is not null and not exists(select 1 from public.erp_business_workspace_branches b where b.id=p_branch_id and b.workspace_id=p_workspace_id and b.is_active) then return false; end if;
 if p_warehouse_id is not null and not exists(select 1 from public.erp_business_workspace_warehouses w where w.id=p_warehouse_id and w.workspace_id=p_workspace_id and w.is_active) then return false; end if;
 if v_branch is null and p_warehouse_id is not null then
  select branch_id into v_branch from public.erp_business_workspace_warehouses where id=p_warehouse_id and workspace_id=p_workspace_id;
 end if;
 select
  exists(select 1 from public.erp_business_workspace_member_locations l where l.workspace_id=p_workspace_id and l.user_id=v_user),
  exists(select 1 from public.erp_business_workspace_member_locations l where l.workspace_id=p_workspace_id and l.user_id=v_user and l.is_allowed)
 into v_has_rules,v_has_allow_rules;
 if not v_has_rules then return true; end if;
 select exists(
  select 1 from public.erp_business_workspace_member_locations l
  join public.erp_business_workspace_warehouses wh on wh.id=l.warehouse_id and wh.workspace_id=l.workspace_id
  where l.workspace_id=p_workspace_id and l.user_id=v_user and l.access_scope='warehouse' and l.is_allowed
   and ((p_warehouse_id is not null and l.warehouse_id=p_warehouse_id) or (p_warehouse_id is null and wh.branch_id=v_branch))
 ) into v_has_allowed_warehouse;
 if exists(select 1 from public.erp_business_workspace_member_locations l where l.workspace_id=p_workspace_id and l.user_id=v_user and l.access_scope='warehouse' and l.warehouse_id=p_warehouse_id and not l.is_allowed) then return false; end if;
 if exists(select 1 from public.erp_business_workspace_member_locations l where l.workspace_id=p_workspace_id and l.user_id=v_user and l.access_scope='branch' and l.branch_id=v_branch and not l.is_allowed) and not v_has_allowed_warehouse then return false; end if;
 -- A member with only deny rules has no permitted location. Never turn a deny-only list into full access.
 if not v_has_allow_rules then return false; end if;
 return exists(select 1 from public.erp_business_workspace_member_locations l where l.workspace_id=p_workspace_id and l.user_id=v_user and l.access_scope='branch' and l.branch_id=v_branch and l.is_allowed)
  or exists(select 1 from public.erp_business_workspace_member_locations l where l.workspace_id=p_workspace_id and l.user_id=v_user and l.access_scope='warehouse' and l.warehouse_id=p_warehouse_id and l.is_allowed)
  or (p_warehouse_id is null and v_has_allowed_warehouse);
end
$$;
revoke all on function private.can_access_business_workspace_location(uuid,uuid,uuid) from public,anon;
grant execute on function private.can_access_business_workspace_location(uuid,uuid,uuid) to authenticated;