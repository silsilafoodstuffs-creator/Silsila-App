create or replace function public.erp_append_app_activity_log(
  p_company_id uuid,
  p_action text,
  p_entity_type text,
  p_entity_id text,
  p_app_id uuid default null,
  p_details jsonb default '{}'::jsonb
)
returns bigint
language plpgsql
security definer
set search_path = public
set row_security = off
as $$
declare
  v_id bigint;
begin
  if auth.uid() is null then
    raise exception 'يجب تسجيل الدخول لتسجيل العملية' using errcode = '42501';
  end if;

  if p_company_id is null
     or not public.erp_user_can_access_company(p_company_id) then
    raise exception 'لا توجد صلاحية لتسجيل عملية على هذه الشركة' using errcode = '42501';
  end if;

  if nullif(btrim(p_action), '') is null
     or nullif(btrim(p_entity_type), '') is null
     or nullif(btrim(p_entity_id), '') is null then
    raise exception 'بيانات سجل العملية غير مكتملة' using errcode = '22023';
  end if;

  if length(p_action) > 120
     or length(p_entity_type) > 120
     or length(p_entity_id) > 240
     or octet_length(coalesce(p_details, '{}'::jsonb)::text) > 8192 then
    raise exception 'تجاوزت بيانات سجل العملية الحدود المسموح بها' using errcode = '22023';
  end if;

  if p_app_id is not null and not exists (
    select 1
    from public.erp_managed_apps a
    where a.id = p_app_id
      and a.company_id = p_company_id
  ) then
    raise exception 'التطبيق المحدد لا يتبع الشركة الحالية' using errcode = '22023';
  end if;

  insert into public.erp_app_activity_log (
    company_id, app_id, actor_id, action, entity_type, entity_id, details
  ) values (
    p_company_id, p_app_id, auth.uid(), btrim(p_action), btrim(p_entity_type),
    btrim(p_entity_id), coalesce(p_details, '{}'::jsonb)
  )
  returning id into v_id;

  return v_id;
end;
$$;

revoke all on function public.erp_append_app_activity_log(uuid,text,text,text,uuid,jsonb) from public, anon;
grant execute on function public.erp_append_app_activity_log(uuid,text,text,text,uuid,jsonb) to authenticated;
