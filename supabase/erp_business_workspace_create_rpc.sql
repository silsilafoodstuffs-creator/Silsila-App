create or replace function public.erp_create_business_workspace(
 p_workspace_name text,
 p_activity_type text default null,
 p_account_kind text default 'customer'
) returns uuid
language plpgsql security definer
set search_path=pg_catalog,public,auth
as $$
declare v_id uuid;
begin
 if (select auth.uid()) is null then raise exception 'Authentication required' using errcode='28000'; end if;
 if length(trim(coalesce(p_workspace_name,''))) not between 2 and 160 then
  raise exception 'Workspace name is invalid' using errcode='22023';
 end if;
 if p_account_kind not in ('customer','supplier','other') then
  raise exception 'Account kind is invalid' using errcode='22023';
 end if;
 insert into public.erp_business_workspaces(owner_user_id,workspace_name,activity_type,account_kind)
 values((select auth.uid()),trim(p_workspace_name),nullif(trim(coalesce(p_activity_type,'')),''),p_account_kind)
 returning id into v_id;
 return v_id;
end;
$$;
revoke all on function public.erp_create_business_workspace(text,text,text) from public,anon;
grant execute on function public.erp_create_business_workspace(text,text,text) to authenticated;
