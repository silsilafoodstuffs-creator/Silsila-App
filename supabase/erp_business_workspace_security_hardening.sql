grant usage on schema private to authenticated;

alter function public.erp_add_business_workspace_member(uuid,text,text,jsonb) set schema private;
revoke all on function private.erp_add_business_workspace_member(uuid,text,text,jsonb) from public,anon;
grant execute on function private.erp_add_business_workspace_member(uuid,text,text,jsonb) to authenticated;
create or replace function public.erp_add_business_workspace_member(
 p_workspace_id uuid,p_phone text,p_role text default 'staff',p_permissions jsonb default '{}'::jsonb
) returns uuid language sql security invoker set search_path=pg_catalog,public,auth,private
as $$ select private.erp_add_business_workspace_member(p_workspace_id,p_phone,p_role,p_permissions); $$;
revoke all on function public.erp_add_business_workspace_member(uuid,text,text,jsonb) from public,anon;
grant execute on function public.erp_add_business_workspace_member(uuid,text,text,jsonb) to authenticated;

create or replace function private.erp_create_business_workspace(
 p_workspace_name text,p_activity_type text default null,p_account_kind text default 'customer'
) returns uuid language plpgsql security definer set search_path=pg_catalog,public,auth,private
as $$
declare v_id uuid; v_user_id uuid;
begin
 v_user_id := (select auth.uid());
 if v_user_id is null then raise exception 'Authentication required' using errcode='28000'; end if;
 if length(trim(coalesce(p_workspace_name,''))) not between 2 and 160 then raise exception 'Workspace name is invalid' using errcode='22023'; end if;
 if p_account_kind not in ('customer','supplier','other') then raise exception 'Account kind is invalid' using errcode='22023'; end if;
 insert into public.erp_business_workspaces(owner_user_id,linked_profile_id,workspace_name,activity_type,account_kind)
 values(v_user_id,v_user_id,trim(p_workspace_name),nullif(trim(coalesce(p_activity_type,'')),''),p_account_kind)
 returning id into v_id;
 return v_id;
end $$;
revoke all on function private.erp_create_business_workspace(text,text,text) from public,anon;
revoke all on function private.erp_create_business_workspace(text,text,text) from public,anon,authenticated;
create or replace function public.erp_create_business_workspace(
 p_workspace_name text,p_activity_type text default null,p_account_kind text default 'customer'
) returns uuid language sql security invoker set search_path=pg_catalog,public,auth,private
as $$ select private.erp_create_business_workspace(p_workspace_name,p_activity_type,p_account_kind); $$;
revoke all on function public.erp_create_business_workspace(text,text,text) from public,anon;
revoke all on function public.erp_create_business_workspace(text,text,text) from public,anon,authenticated;

create or replace function private.erp_remove_business_workspace_member(p_workspace_id uuid,p_member_user_id uuid)
returns boolean language plpgsql security definer set search_path=pg_catalog,public,auth,private
as $$
begin
 if (select auth.uid()) is null then raise exception 'Authentication required' using errcode='28000'; end if;
 if not private.is_business_workspace_owner(p_workspace_id) then raise exception 'Only the workspace owner can remove members' using errcode='42501'; end if;
 if p_member_user_id=(select auth.uid()) then raise exception 'The workspace owner cannot remove themselves' using errcode='22023'; end if;
 delete from public.erp_business_workspace_members where workspace_id=p_workspace_id and user_id=p_member_user_id;
 return found;
end $$;
revoke all on function private.erp_remove_business_workspace_member(uuid,uuid) from public,anon;
grant execute on function private.erp_remove_business_workspace_member(uuid,uuid) to authenticated;
create or replace function public.erp_remove_business_workspace_member(p_workspace_id uuid,p_member_user_id uuid)
returns boolean language sql security invoker set search_path=pg_catalog,public,auth,private
as $$ select private.erp_remove_business_workspace_member(p_workspace_id,p_member_user_id); $$;
revoke all on function public.erp_remove_business_workspace_member(uuid,uuid) from public,anon;
grant execute on function public.erp_remove_business_workspace_member(uuid,uuid) to authenticated;
