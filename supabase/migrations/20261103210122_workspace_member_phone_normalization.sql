-- Normalize Egyptian phone digits and formats consistently when linking
-- existing Silsila accounts to a business workspace. Include every permission
-- key exposed by the workspace member-permissions UI.
create or replace function private.normalize_phone_for_profile_match(p_phone text)
returns text
language sql
immutable
parallel safe
strict
set search_path = ''
as $function$
  with digits as (
    select pg_catalog.regexp_replace(
      pg_catalog.translate(
        p_phone,
        '٠١٢٣٤٥٦٧٨٩۰۱۲۳۴۵۶۷۸۹',
        '01234567890123456789'
      ),
      '[^0-9]', '', 'g'
    ) as value
  )
  select case
    when value like '0020%' then pg_catalog.substr(value,5)
    when value like '20%' and pg_catalog.length(value)=12 then pg_catalog.substr(value,3)
    when value like '0%' and pg_catalog.length(value)=11 then pg_catalog.substr(value,2)
    else value
  end
  from digits
$function$;

create or replace function private.erp_add_business_workspace_member(
 p_workspace_id uuid,
 p_phone text,
 p_role text default 'staff',
 p_permissions jsonb default '{}'::jsonb
) returns uuid
language plpgsql
security definer
set search_path=pg_catalog,public,auth
as $function$
declare
 v_actor uuid;
 v_user_id uuid;
 v_name text;
 v_member_id uuid;
 v_allowed text[]:=array[
  'workspace.enter','members.read','members.manage','master.read','master.manage',
  'items.read','items.propose','inventory.read','inventory.manage',
  'purchases.read','purchases.manage','sales.read','sales.manage',
  'cash.read','cash.manage','hr.read','hr.manage','reports.read','audit.read','audit.write',
  'customers.read','customers.manage','suppliers.read','suppliers.manage'
 ];
begin
 v_actor:=(select auth.uid());
 if v_actor is null then raise exception 'Authentication required' using errcode='28000'; end if;
 if not exists(
   select 1 from public.erp_business_workspaces w
   where w.id=p_workspace_id and w.owner_user_id=v_actor and w.is_active
 ) then
  raise exception 'Only the workspace owner can manage members' using errcode='42501';
 end if;
 if p_role not in ('admin','manager','accountant','warehouse','sales','viewer','staff') then
  raise exception 'Member role is invalid' using errcode='22023';
 end if;
 if jsonb_typeof(coalesce(p_permissions,'{}'::jsonb))<>'object' then
  raise exception 'Permissions must be a JSON object' using errcode='22023';
 end if;
 if exists(
   select 1 from jsonb_each(coalesce(p_permissions,'{}'::jsonb)) e
   where not(e.key=any(v_allowed)) or jsonb_typeof(e.value)<>'boolean'
 ) then
  raise exception 'Unknown or invalid permission key' using errcode='22023';
 end if;
 select p.id,p.full_name into v_user_id,v_name
 from public.profiles p
 where private.normalize_phone_for_profile_match(p.phone)=
       private.normalize_phone_for_profile_match(p_phone)
   and p.account_status='active'
 limit 1;
 if v_user_id is null then
  raise exception 'No active registered Silsila account matches this phone number' using errcode='P0002';
 end if;
 if v_user_id=v_actor then
  raise exception 'The workspace owner is already a member' using errcode='22023';
 end if;
 insert into public.erp_business_workspace_members(
  workspace_id,user_id,member_role,is_active,can_open_workspace,permissions,
  created_by,member_display_name
 ) values(
  p_workspace_id,v_user_id,p_role,true,true,coalesce(p_permissions,'{}'::jsonb),
  v_actor,v_name
 )
 on conflict(workspace_id,user_id) do update set
  member_role=excluded.member_role,is_active=true,can_open_workspace=true,
  permissions=excluded.permissions,created_by=v_actor,
  member_display_name=excluded.member_display_name,updated_at=now()
 returning id into v_member_id;
 return v_member_id;
end
$function$;

revoke all on function private.erp_add_business_workspace_member(uuid,text,text,jsonb) from public,anon;
grant execute on function private.erp_add_business_workspace_member(uuid,text,text,jsonb) to authenticated;
