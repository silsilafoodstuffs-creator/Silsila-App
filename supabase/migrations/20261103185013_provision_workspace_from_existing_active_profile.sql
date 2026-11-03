create unique index if not exists erp_business_workspaces_linked_profile_uidx
  on public.erp_business_workspaces(linked_profile_id)
  where linked_profile_id is not null;

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
  if new.account_status <> 'active' then
    return new;
  end if;

  if lower(coalesce(new.role,'')) not in ('customer','supplier','delegate','shipping_company') then
    return new;
  end if;

  if nullif(btrim(coalesce(new.full_name,'')),'') is null
     or nullif(btrim(coalesce(new.activity_type,'')),'') is null then
    return new;
  end if;

  v_kind := case lower(new.role)
    when 'supplier' then 'supplier'
    when 'customer' then 'customer'
    else 'other'
  end;

  select coalesce(
    nullif(btrim(sd.business_name),''),
    nullif(btrim(new.full_name),'')
  )
  into v_workspace_name
  from (select 1) seed
  left join public.supplier_details sd on sd.supplier_id=new.id;

  select cm.company_id
  into v_platform_company_id
  from public.erp_company_members cm
  join public.profiles manager on manager.id=cm.user_id
  where manager.role in ('management','admin')
    and manager.account_status='active'
    and cm.is_active
  order by cm.created_at
  limit 1;

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

revoke all on function private.provision_business_workspace_for_active_profile() from public,anon,authenticated;

drop trigger if exists silsila_provision_business_workspace on public.profiles;
create trigger silsila_provision_business_workspace
after insert or update of account_status,account_type,activity_type,full_name,role
on public.profiles
for each row
execute function private.provision_business_workspace_for_active_profile();

create or replace function private.sync_workspace_name_from_supplier_details()
returns trigger
language plpgsql
security definer
set search_path = ''
as $function$
begin
  if nullif(btrim(coalesce(new.business_name,'')),'') is not null then
    update public.erp_business_workspaces
    set workspace_name=btrim(new.business_name),updated_at=now()
    where linked_profile_id=new.supplier_id
      and owner_user_id=new.supplier_id;
  end if;
  return new;
end
$function$;

revoke all on function private.sync_workspace_name_from_supplier_details() from public,anon,authenticated;

drop trigger if exists silsila_sync_workspace_name_from_supplier_details on public.supplier_details;
create trigger silsila_sync_workspace_name_from_supplier_details
after insert or update of business_name
on public.supplier_details
for each row
execute function private.sync_workspace_name_from_supplier_details();

insert into public.erp_business_workspaces(
  owner_user_id,linked_profile_id,platform_company_id,
  workspace_name,activity_type,account_kind,is_active
)
select
  p.id,p.id,
  (select cm.company_id
   from public.erp_company_members cm
   join public.profiles manager on manager.id=cm.user_id
   where manager.role in ('management','admin')
     and manager.account_status='active'
     and cm.is_active
   order by cm.created_at limit 1),
  coalesce(nullif(btrim(sd.business_name),''),nullif(btrim(p.full_name),'')),
  btrim(p.activity_type),
  case lower(p.role) when 'supplier' then 'supplier' when 'customer' then 'customer' else 'other' end,
  true
from public.profiles p
left join public.supplier_details sd on sd.supplier_id=p.id
where p.account_status='active'
  and lower(coalesce(p.role,'')) in ('customer','supplier','delegate','shipping_company')
  and nullif(btrim(coalesce(p.full_name,'')),'') is not null
  and nullif(btrim(coalesce(p.activity_type,'')),'') is not null
on conflict (linked_profile_id) where linked_profile_id is not null do nothing;
