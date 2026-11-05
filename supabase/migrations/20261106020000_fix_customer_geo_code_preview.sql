-- Align customer-code preview with the geographic_area_id used by the insert trigger.
-- Also restrict execution to authenticated company members.
create or replace function public.erp_preview_next_customer_geo_code(p_company_id uuid,p_geo_area_id uuid)
returns text
language plpgsql
security definer
set search_path=''
as $$
declare
  v_geo_code text;
  v_prefix text := 'Cus';
  v_digits integer := 4;
  v_policy text;
  v_max bigint;
begin
  if auth.uid() is null or not public.erp_user_can_access_company(p_company_id) then
    raise exception 'غير مصرح بمعاينة أكواد هذه الشركة';
  end if;

  select g.hierarchical_code
    into v_geo_code
  from public.erp_geographic_data g
  where g.id = p_geo_area_id
    and g.company_id = p_company_id
    and g.level = 'area'
    and g.is_active = true;

  if v_geo_code is null or v_geo_code !~ '^[0-9]{8}$' then
    raise exception 'اختر منطقة فعالة لها كود جغرافي من 8 أرقام';
  end if;

  select p.policy_value
    into v_policy
  from public.erp_program_policies p
  where p.company_id = p_company_id
    and p.policy_key = 'code_generation_registry'
  limit 1;

  if v_policy is not null and left(v_policy, 1) = '{' then
    v_prefix := coalesce(nullif(v_policy::jsonb #>> '{types,customer,prefix}', ''), 'Cus');
    v_digits := coalesce(nullif(v_policy::jsonb #>> '{types,customer,digits}', '')::integer, 4);
  end if;

  if v_digits < 1 or v_digits > 8 or v_prefix !~ '^[A-Za-z]+$' then
    raise exception 'إعدادات كود العميل غير صحيحة';
  end if;

  select coalesce(max(substring(p.party_code from (length(v_prefix || v_geo_code) + 1))::bigint), 0)
    into v_max
  from public.erp_parties p
  where p.company_id = p_company_id
    and p.party_kind = 'customer'
    and p.geographic_area_id = p_geo_area_id
    and p.party_code ~ ('^' || v_prefix || v_geo_code || '[0-9]+$');

  if v_max + 1 >= power(10::numeric, v_digits) then
    raise exception 'انتهت خانات تسلسل العملاء داخل هذه المنطقة؛ زد عدد الخانات من سياسات التكويد';
  end if;

  return v_prefix || v_geo_code || lpad((v_max + 1)::text, v_digits, '0');
end;
$$;

revoke all on function public.erp_preview_next_customer_geo_code(uuid,uuid) from public;
revoke all on function public.erp_preview_next_customer_geo_code(uuid,uuid) from anon;
grant execute on function public.erp_preview_next_customer_geo_code(uuid,uuid) to authenticated;
