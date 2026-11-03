-- Resolve both legacy activity labels and canonical activity codes, then
-- persist only the canonical code on each provisioned workspace.
create or replace function private.provision_business_workspace_for_active_profile()
returns trigger
language plpgsql
security definer
set search_path=''
as $function$
declare
  v_kind text;
  v_workspace_name text;
  v_platform_company_id uuid;
  v_activity_code text;
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

  select a.code into v_activity_code
  from public.activity_types a
  where a.is_active
    and (
      lower(btrim(a.code))=lower(btrim(new.activity_type))
      or lower(btrim(a.name))=lower(btrim(new.activity_type))
      or lower(btrim(coalesce(a.name_en,'')))=lower(btrim(new.activity_type))
    )
  order by case
    when lower(btrim(a.code))=lower(btrim(new.activity_type)) then 0
    else 1
  end
  limit 1;

  if v_activity_code is null then
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
    v_workspace_name,v_activity_code,v_kind,true
  )
  on conflict (linked_profile_id) where linked_profile_id is not null do nothing;

  return new;
end
$function$;
