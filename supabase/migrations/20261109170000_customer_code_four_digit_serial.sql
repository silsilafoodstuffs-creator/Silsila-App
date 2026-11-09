-- Customer codes inherit the full 8-digit geographic area code and append a 4-digit serial.
create or replace function public.erp_assign_customer_geo_code()
returns trigger language plpgsql security definer set search_path=''
as $$
declare
  v_geo_code text;
  v_prefix text:='Cus';
  v_digits integer:=4;
  v_policy text;
  v_max bigint;
  v_lock text;
begin
  if coalesce(new.party_kind,'')<>'customer' then return new; end if;
  if tg_op='UPDATE' and new.geographic_area_id is not distinct from old.geographic_area_id then return new; end if;
  if new.geographic_area_id is null then
    raise exception 'اختيار المنطقة مطلوب لتوليد كود العميل المرتبط بالتقسيم الجغرافي';
  end if;

  select hierarchical_code into v_geo_code
  from public.erp_geographic_data
  where id=new.geographic_area_id and company_id=new.company_id
    and level='area' and is_active=true;

  if v_geo_code is null or v_geo_code !~ '^[0-9]{8}$' then
    raise exception 'المنطقة المختارة لا تحتوي على كود جغرافي صحيح من 8 أرقام';
  end if;

  select policy_value into v_policy
  from public.erp_program_policies
  where company_id=new.company_id and policy_key='code_generation_registry'
  limit 1;

  if v_policy is not null and left(v_policy,1)='{' then
    v_prefix:=coalesce(nullif(v_policy::jsonb #>> '{types,customer,prefix}',''),'Cus');
    v_digits:=coalesce(nullif(v_policy::jsonb #>> '{types,customer,digits}','')::integer,4);
  end if;

  if v_prefix<>'Cus' or v_digits<>4 then
    raise exception 'سياسة كود العميل ثابتة على Cus + كود المنطقة (8 أرقام) + تسلسل (4 أرقام)';
  end if;

  v_lock:=new.company_id::text||':customer:'||new.geographic_area_id::text;
  perform pg_advisory_xact_lock(hashtextextended(v_lock,0));

  select coalesce(max(substring(party_code from (length(v_prefix||v_geo_code)+1))::bigint),0)
    into v_max
  from public.erp_parties
  where company_id=new.company_id and party_kind='customer'
    and geographic_area_id=new.geographic_area_id
    and party_code ~ ('^'||v_prefix||v_geo_code||'[0-9]{4}$')
    and (tg_op='INSERT' or id<>new.id);

  if coalesce(v_max,0)+1>=10000 then
    raise exception 'انتهت أرقام تسلسل العملاء الأربعة داخل هذه المنطقة';
  end if;

  new.party_code:=v_prefix||v_geo_code||lpad((coalesce(v_max,0)+1)::text,4,'0');
  return new;
end;
$$;

create or replace function public.erp_preview_next_customer_geo_code(p_company_id uuid,p_geo_area_id uuid)
returns text language plpgsql security definer set search_path=''
as $$
declare
  v_geo_code text;
  v_prefix text:='Cus';
  v_digits integer:=4;
  v_policy text;
  v_max bigint;
begin
  if auth.uid() is null or not public.erp_user_can_access_company(p_company_id) then
    raise exception 'غير مصرح بمعاينة أكواد هذه الشركة';
  end if;

  select hierarchical_code into v_geo_code
  from public.erp_geographic_data
  where id=p_geo_area_id and company_id=p_company_id
    and level='area' and is_active=true;

  if v_geo_code is null or v_geo_code !~ '^[0-9]{8}$' then
    raise exception 'اختر منطقة فعالة لها كود جغرافي من 8 أرقام';
  end if;

  select policy_value into v_policy
  from public.erp_program_policies
  where company_id=p_company_id and policy_key='code_generation_registry'
  limit 1;

  if v_policy is not null and left(v_policy,1)='{' then
    v_prefix:=coalesce(nullif(v_policy::jsonb #>> '{types,customer,prefix}',''),'Cus');
    v_digits:=coalesce(nullif(v_policy::jsonb #>> '{types,customer,digits}','')::integer,4);
  end if;

  if v_prefix<>'Cus' or v_digits<>4 then
    raise exception 'سياسة كود العميل ثابتة على Cus + كود المنطقة (8 أرقام) + تسلسل (4 أرقام)';
  end if;

  select coalesce(max(substring(party_code from (length(v_prefix||v_geo_code)+1))::bigint),0)
    into v_max
  from public.erp_parties
  where company_id=p_company_id and party_kind='customer'
    and geographic_area_id=p_geo_area_id
    and party_code ~ ('^'||v_prefix||v_geo_code||'[0-9]{4}$');

  if coalesce(v_max,0)+1>=10000 then
    raise exception 'انتهت أرقام تسلسل العملاء الأربعة داخل هذه المنطقة';
  end if;

  return v_prefix||v_geo_code||lpad((coalesce(v_max,0)+1)::text,4,'0');
end;
$$;

grant execute on function public.erp_preview_next_customer_geo_code(uuid,uuid) to authenticated;


-- Keep saved coding-policy JSON in sync with the enforced 4-digit customer serial.
update public.erp_program_policies
set policy_value = jsonb_set(
  jsonb_set(
    jsonb_set(
      jsonb_set(policy_value::jsonb, '{types,customer,digits}', '4'::jsonb, true),
      '{types,customer,serial_digits}', '4'::jsonb, true
    ),
    '{types,customer,fields,1,digits}', '4'::jsonb, true
  ),
  '{customer_code,serial_digits}', '4'::jsonb, true
)::text
where policy_key = 'code_generation_registry'
  and policy_value is not null
  and left(policy_value,1) = '{';
