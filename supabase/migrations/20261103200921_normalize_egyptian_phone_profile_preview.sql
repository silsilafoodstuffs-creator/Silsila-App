create or replace function private.normalize_phone_for_profile_match(p_phone text)
returns text
language sql
immutable
strict
parallel safe
set search_path = ''
as $function$
  with digits as (
    select pg_catalog.regexp_replace(p_phone,'[^0-9]','','g') as value
  )
  select case
    when value like '0020%' then pg_catalog.substr(value,5)
    when value like '20%' and pg_catalog.length(value)=12 then pg_catalog.substr(value,3)
    when value like '0%' and pg_catalog.length(value)=11 then pg_catalog.substr(value,2)
    else value
  end
  from digits
$function$;
revoke all on function private.normalize_phone_for_profile_match(text) from public,anon,authenticated;

create index if not exists idx_profiles_phone_workspace_match
  on public.profiles(private.normalize_phone_for_profile_match(phone));
create index if not exists idx_profiles_whatsapp_workspace_match
  on public.profiles(private.normalize_phone_for_profile_match(whatsapp_phone));

create or replace function private.find_silsila_profile_name_by_phone(p_workspace_id uuid,p_phone text)
returns table(profile_name text)
language plpgsql
stable
security definer
set search_path = ''
as $function$
declare
  v_phone text := private.normalize_phone_for_profile_match(coalesce(p_phone,''));
begin
  if (select auth.uid()) is null then
    raise exception 'Authentication required' using errcode='28000';
  end if;

  if private.is_silsila_workspace_observer() then
    raise exception 'Read-only observers cannot perform phone lookups' using errcode='42501';
  end if;

  if not (
    private.can_access_business_workspace(p_workspace_id,'customers.read')
    or private.can_access_business_workspace(p_workspace_id,'suppliers.read')
  ) then
    raise exception 'Insufficient permission to preview Silsila contact matches' using errcode='42501';
  end if;

  if pg_catalog.length(coalesce(v_phone,'')) < 10 then
    return;
  end if;

  return query
  select p.full_name
  from public.profiles p
  where private.normalize_phone_for_profile_match(coalesce(p.phone,''))=v_phone
     or private.normalize_phone_for_profile_match(coalesce(p.whatsapp_phone,''))=v_phone
  limit 1;
end
$function$;
