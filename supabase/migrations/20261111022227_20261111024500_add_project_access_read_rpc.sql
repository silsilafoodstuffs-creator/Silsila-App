create or replace function public.erp_get_user_project_access(
  p_company_id uuid,
  p_user_id uuid
)
returns table (
  project_id uuid,
  project_code text,
  project_name text,
  project_status text,
  is_allowed boolean
)
language plpgsql
security definer
set search_path = ''
set row_security = off
as $function$
begin
  if auth.uid() is null
     or not public.erp_user_has_company_role(
       p_company_id, array['owner','admin','manager']::text[]
     ) then
    raise exception 'غير مصرح بعرض تخصيصات المشروعات';
  end if;

  if not exists (
    select 1 from public.erp_users u
    where u.id = p_user_id
      and u.company_id = p_company_id
      and u.is_active = true
  ) then
    raise exception 'المستخدم المستهدف غير نشط أو لا يتبع الشركة';
  end if;

  return query
  select p.id, p.project_code, p.name, p.status,
         coalesce(a.is_allowed, false)
  from public.erp_construction_projects p
  left join public.erp_user_project_access a
    on a.company_id = p.company_id
   and a.project_id = p.id
   and a.user_id = p_user_id
  where p.company_id = p_company_id
  order by p.project_code, p.name;
end;
$function$;

revoke all on function public.erp_get_user_project_access(uuid, uuid) from public, anon;
grant execute on function public.erp_get_user_project_access(uuid, uuid) to authenticated;