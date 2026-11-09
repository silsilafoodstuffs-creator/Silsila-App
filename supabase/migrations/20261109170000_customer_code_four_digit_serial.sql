-- Keep the customer code serial at the explicitly approved two digits.
-- This later compatibility migration must not restore the superseded four-digit format.
do $$
declare
  v_def text;
begin
  v_def := pg_get_functiondef('public.erp_assign_customer_geo_code()'::regprocedure);
  v_def := replace(v_def,'v_digits integer:=4;','v_digits integer:=2;');
  v_def := replace(v_def,'::integer,4);','::integer,2);');
  v_def := replace(v_def,'v_digits<>4','v_digits<>2');
  v_def := replace(v_def,'[0-9]{4}$','[0-9]{2}$');
  v_def := replace(v_def,'>=10000 then','>=100 then');
  v_def := replace(v_def,'::text,4,','::text,2,');
  v_def := replace(v_def,'تسلسل (4 أرقام)','تسلسل (رقمين)');
  v_def := replace(v_def,'أرقام تسلسل العملاء الأربعة','أرقام تسلسل العملاء المكونة من رقمين');
  if position('v_digits<>2' in v_def)=0
     or position('[0-9]{2}$' in v_def)=0
     or position('::text,2,' in v_def)=0 then
    raise exception 'Customer code trigger must use a two-digit serial';
  end if;
  execute v_def;

  v_def := pg_get_functiondef('public.erp_preview_next_customer_geo_code(uuid,uuid)'::regprocedure);
  v_def := replace(v_def,'v_digits integer:=4;','v_digits integer:=2;');
  v_def := replace(v_def,'::integer,4);','::integer,2);');
  v_def := replace(v_def,'v_digits<>4','v_digits<>2');
  v_def := replace(v_def,'[0-9]{4}$','[0-9]{2}$');
  v_def := replace(v_def,'>=10000 then','>=100 then');
  v_def := replace(v_def,'::text,4,','::text,2,');
  v_def := replace(v_def,'تسلسل (4 أرقام)','تسلسل (رقمين)');
  v_def := replace(v_def,'أرقام تسلسل العملاء الأربعة','أرقام تسلسل العملاء المكونة من رقمين');
  if position('v_digits<>2' in v_def)=0
     or position('[0-9]{2}$' in v_def)=0
     or position('::text,2,' in v_def)=0 then
    raise exception 'Customer code preview must use a two-digit serial';
  end if;
  execute v_def;
end $$;

update public.erp_program_policies p
set policy_value=jsonb_set(
  jsonb_set(
    jsonb_set(
      jsonb_set(p.policy_value::jsonb,
        '{types,customer,digits}','2'::jsonb,true),
      '{types,customer,serial_digits}','2'::jsonb,true),
    '{types,customer,fields,1,digits}','2'::jsonb,true),
  '{customer_code,serial_digits}','2'::jsonb,true
)::text,
updated_at=now()
where p.policy_key='code_generation_registry'
  and p.policy_value is not null and left(p.policy_value,1)='{';
