alter table public.erp_business_workspaces
 add column if not exists platform_company_id uuid references public.erp_companies(id) on delete set null;
update public.erp_business_workspaces w
set platform_company_id=(select cm.company_id from public.erp_company_members cm join public.profiles p on p.id=cm.user_id where p.role='management' and p.account_status='active' and cm.is_active order by cm.created_at limit 1)
where w.platform_company_id is null;

create or replace function private.erp_create_business_workspace(
 p_workspace_name text,p_activity_type text default null,p_account_kind text default 'customer'
) returns uuid language plpgsql security definer
set search_path=pg_catalog,public,auth,private
as $$
declare v_id uuid; v_user_id uuid; v_platform_company_id uuid;
begin
 v_user_id := (select auth.uid());
 if v_user_id is null then raise exception 'Authentication required' using errcode='28000'; end if;
 if length(trim(coalesce(p_workspace_name,''))) not between 2 and 160 then raise exception 'Workspace name is invalid' using errcode='22023'; end if;
 if p_account_kind not in ('customer','supplier','other') then raise exception 'Account kind is invalid' using errcode='22023'; end if;
 select cm.company_id into v_platform_company_id from public.erp_company_members cm
 join public.profiles p on p.id=cm.user_id
 where p.role='management' and p.account_status='active' and cm.is_active
 order by cm.created_at limit 1;
 insert into public.erp_business_workspaces(owner_user_id,linked_profile_id,platform_company_id,workspace_name,activity_type,account_kind)
 values(v_user_id,v_user_id,v_platform_company_id,trim(p_workspace_name),nullif(trim(coalesce(p_activity_type,'')),''),p_account_kind)
 returning id into v_id;
 return v_id;
end;
$$;
