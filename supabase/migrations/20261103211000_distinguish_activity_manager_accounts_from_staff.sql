create or replace function private.is_silsila_platform_user(p_user_id uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $function$
  select exists (
    select 1
    from public.profiles p
    join public.erp_company_members cm on cm.user_id=p.id and cm.is_active
    where p.id=p_user_id
      and p.account_status = any(array['approved','active','مفعل','معتمد']::text[])
      and lower(coalesce(p.role,'')) in ('management','admin','administrator','super_admin','superadmin','employee','staff')
      and lower(coalesce(p.account_type,'')) not in ('إدارة نشاط','activity_manager','business_owner')
      and cm.company_id=private.silsila_platform_company_id()
  );
$function$;
revoke all on function private.is_silsila_platform_user(uuid) from public,anon,authenticated;

create or replace function private.is_silsila_workspace_observer()
returns boolean
language sql
stable
security definer
set search_path = ''
as $function$
  select private.is_silsila_platform_user((select auth.uid()));
$function$;
revoke all on function private.is_silsila_workspace_observer() from public,anon,authenticated;

create or replace function private.provision_business_workspace_for_active_profile()
returns trigger
language plpgsql
security definer
set search_path = ''
as $function$
declare
  v_kind text;
  v_workspace_name text;
  v_platform_company_id uuid;
begin
  if new.account_status <> all(array['approved','active','مفعل','معتمد']::text[]) then
    return new;
  end if;

  if lower(coalesce(new.role,'')) not in ('customer','supplier','delegate','shipping_company','management') then
    return new;
  end if;

  if private.is_silsila_platform_user(new.id) then
    return new;
  end if;

  if nullif(btrim(coalesce(new.full_name,'')),'') is null
     or nullif(btrim(coalesce(new.activity_type,'')),'') is null then
    return new;
  end if;

  v_platform_company_id := private.silsila_platform_company_id();
  v_kind := case lower(new.role)
    when 'supplier' then 'supplier'
    when 'customer' then 'customer'
    else 'other'
  end;

  select coalesce(nullif(btrim(sd.business_name),''),nullif(btrim(new.full_name),''))
  into v_workspace_name
  from (select 1) seed
  left join public.supplier_details sd on sd.supplier_id=new.id;

  insert into public.erp_business_workspaces(
    owner_user_id,linked_profile_id,platform_company_id,
    workspace_name,activity_type,account_kind,is_active
  )
  values(
    new.id,new.id,v_platform_company_id,
    v_workspace_name,btrim(new.activity_type),v_kind,true
  )
  on conflict (linked_profile_id) where linked_profile_id is not null do nothing;

  return new;
end
$function$;

insert into public.erp_business_workspaces(
  owner_user_id,linked_profile_id,platform_company_id,
  workspace_name,activity_type,account_kind,is_active
)
select
  p.id,p.id,private.silsila_platform_company_id(),
  coalesce(nullif(btrim(sd.business_name),''),nullif(btrim(p.full_name),'')),
  btrim(p.activity_type),
  case lower(p.role) when 'supplier' then 'supplier' when 'customer' then 'customer' else 'other' end,
  true
from public.profiles p
left join public.supplier_details sd on sd.supplier_id=p.id
where p.account_status = any(array['approved','active','مفعل','معتمد']::text[])
  and lower(coalesce(p.role,'')) in ('customer','supplier','delegate','shipping_company','management')
  and nullif(btrim(coalesce(p.full_name,'')),'') is not null
  and nullif(btrim(coalesce(p.activity_type,'')),'') is not null
  and not private.is_silsila_platform_user(p.id)
on conflict (linked_profile_id) where linked_profile_id is not null do nothing;
