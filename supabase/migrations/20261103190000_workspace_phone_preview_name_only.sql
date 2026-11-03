drop function if exists public.erp_find_silsila_profile_by_phone(uuid,text);
drop function if exists private.find_silsila_profile_by_phone(uuid,text);
create or replace function private.find_silsila_profile_name_by_phone(p_workspace_id uuid,p_phone text)
returns table(profile_name text) language plpgsql stable security definer set search_path = ''
as $function$
declare v_phone text := pg_catalog.regexp_replace(pg_catalog.coalesce(p_phone,''),'[^0-9+]','','g');
begin
 if (select auth.uid()) is null then raise exception 'Authentication required' using errcode='28000'; end if;
 if not (private.can_access_business_workspace(p_workspace_id,'customers.read') or private.can_access_business_workspace(p_workspace_id,'suppliers.read')) then
  raise exception 'Insufficient permission to preview Silsila contact matches' using errcode='42501';
 end if;
 if pg_catalog.length(pg_catalog.regexp_replace(v_phone,'[^0-9]','','g')) < 10 then return; end if;
 return query select p.full_name from public.profiles p
 where pg_catalog.regexp_replace(pg_catalog.coalesce(p.phone,''),'[^0-9+]','','g')=v_phone
    or pg_catalog.regexp_replace(pg_catalog.coalesce(p.whatsapp_phone,''),'[^0-9+]','','g')=v_phone limit 1;
end $function$;
create or replace function public.erp_find_silsila_profile_by_phone(p_workspace_id uuid,p_phone text)
returns table(profile_name text) language sql stable security invoker set search_path = ''
as $function$ select * from private.find_silsila_profile_name_by_phone(p_workspace_id,p_phone); $function$;
revoke all on function private.find_silsila_profile_name_by_phone(uuid,text) from public, anon;
grant execute on function private.find_silsila_profile_name_by_phone(uuid,text) to authenticated;
revoke all on function public.erp_find_silsila_profile_by_phone(uuid,text) from public, anon;
grant execute on function public.erp_find_silsila_profile_by_phone(uuid,text) to authenticated;
