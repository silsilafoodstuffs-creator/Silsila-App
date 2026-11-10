UPDATE public.erp_program_policies
SET policy_value=jsonb_set(
  jsonb_set(policy_value::jsonb,'{serial_digits}','4'::jsonb,true),
  '{geo_digits}','8'::jsonb,true
)::text,
category='تكويدية',
updated_at=now()
WHERE policy_key='customer_code'
  AND left(policy_value,1)='{';

UPDATE public.erp_program_policies
SET policy_value=jsonb_set(
  jsonb_set(
    jsonb_set(policy_value::jsonb,'{types,customer,digits}','4'::jsonb,true),
    '{customer_code,serial_digits}','4'::jsonb,true
  ),
  '{customer_code,geo_digits}','8'::jsonb,true
)::text,
category='تكويدية',
name_ar='سياسات التكويد المركزي',
updated_at=now()
WHERE policy_key='code_generation_registry'
  AND left(policy_value,1)='{';
