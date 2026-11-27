-- Company profile code generation follows the company-specific code_policy.company value.
create or replace function public.erp_assign_company_code(p_company_id uuid)
returns text language plpgsql security definer set search_path = '' as $$
declare
  v_existing text;
  v_policy text;
  v_prefix text;
  v_digits integer;
  v_next bigint;
  v_code text;
  v_user uuid := auth.uid();
begin
  if v_user is null or not public.erp_user_has_company_role(p_company_id, array['owner','admin']::text[]) then
    raise exception 'غير مصرح بتوليد كود الشركة';
  end if;
  select nullif(btrim(s.setting_value->>'company_code'),'') into v_existing
  from public.erp_company_settings s
  where s.company_id=p_company_id and s.setting_key='company_profile_extra';
  if v_existing is not null then return v_existing; end if;
  select p.policy_value into v_policy from public.erp_program_policies p
  where p.company_id=p_company_id and p.policy_key='code_policy.company' limit 1;
  v_prefix := (regexp_match(coalesce(v_policy,'Com + 2 أرقام تسلسلية'),'[A-Za-z]{3}'))[1];
  v_digits := coalesce(((regexp_match(coalesce(v_policy,'Com + 2 أرقام تسلسلية'),'([0-9]+)'))[1])::integer,2);
  if v_prefix is null or v_digits < 1 or v_digits > 6 then
    raise exception 'سياسة كود الشركة غير صحيحة؛ راجع سياسات التكويد';
  end if;
  perform pg_advisory_xact_lock(hashtextextended('silsila:company-code:'||v_prefix,0));
  select coalesce(max(((regexp_match(s.setting_value->>'company_code','^[A-Za-z]{3}([0-9]+)$'))[1])::bigint),0)
    into v_next from public.erp_company_settings s
    where s.setting_key='company_profile_extra'
      and s.setting_value->>'company_code' ~ ('^'||v_prefix||'[0-9]+$');
  if v_next+1 >= power(10::numeric,v_digits) then
    raise exception 'انتهت خانات كود الشركة وفق سياسة التكويد؛ عدّل السياسة قبل إضافة شركة أخرى';
  end if;
  v_code := v_prefix||lpad((v_next+1)::text,v_digits,'0');
  insert into public.erp_company_settings(company_id,setting_key,setting_value,updated_by)
  values(p_company_id,'company_profile_extra',jsonb_build_object('company_code',v_code),v_user)
  on conflict(company_id,setting_key) do update
    set setting_value=coalesce(public.erp_company_settings.setting_value,'{}'::jsonb)||jsonb_build_object('company_code',v_code),
        updated_by=excluded.updated_by;
  return v_code;
end;
$$;
revoke all on function public.erp_assign_company_code(uuid) from public, anon;
grant execute on function public.erp_assign_company_code(uuid) to authenticated;
create unique index if not exists erp_company_profile_extra_code_uidx
on public.erp_company_settings ((setting_value->>'company_code'))
where setting_key='company_profile_extra' and nullif(setting_value->>'company_code','') is not null;
