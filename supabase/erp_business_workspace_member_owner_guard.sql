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
revoke all on function private.is_business_workspace_owner(uuid) from public,anon;
grant execute on function private.is_business_workspace_owner(uuid) to authenticated;
alter policy workspace_insert on public.erp_business_workspace_members with check(private.is_business_workspace_owner(workspace_id));
alter policy workspace_update on public.erp_business_workspace_members using(private.is_business_workspace_owner(workspace_id)) with check(private.is_business_workspace_owner(workspace_id));
alter policy workspace_delete on public.erp_business_workspace_members using(private.is_business_workspace_owner(workspace_id));
create or replace function private.guard_business_workspace_owner_role()
returns trigger language plpgsql security definer set search_path=pg_catalog,public,auth,private
as $$
begin
 if new.member_role='owner' and (private.is_silsila_platform_user(new.user_id) or not exists(select 1 from public.erp_business_workspaces w where w.id=new.workspace_id and w.owner_user_id=new.user_id)) then
  raise exception 'Only the registered workspace owner can hold the owner role' using errcode='42501';
 end if;
 return new;
end $$;
revoke all on function private.guard_business_workspace_owner_role() from public,anon,authenticated;
do $$ begin
 if not exists(select 1 from pg_trigger where tgname='erp_business_workspace_member_owner_guard') then
  create trigger erp_business_workspace_member_owner_guard before insert or update of member_role,user_id,workspace_id
  on public.erp_business_workspace_members for each row execute function private.guard_business_workspace_owner_role();
 end if;
end $$;
