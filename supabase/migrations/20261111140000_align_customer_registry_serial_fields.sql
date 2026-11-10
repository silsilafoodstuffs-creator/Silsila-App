BEGIN;

-- The dedicated customer policy and the central registry are both edited from
-- Program Policies > Coding. Keep the registry's nested field metadata in sync
-- with the same persisted customer_code policy so previews and generators do
-- not retain the obsolete two-digit serial metadata.
UPDATE public.erp_program_policies registry
SET policy_value = jsonb_set(
  registry.policy_value::jsonb,
  '{types,customer}',
  coalesce(registry.policy_value::jsonb #> '{types,customer}', '{}'::jsonb)
  || jsonb_build_object(
    'prefix', coalesce(
      nullif(customer_policy.policy_value::jsonb->>'prefix',''),
      nullif(registry.policy_value::jsonb #>> '{types,customer,prefix}',''),
      'Cus'
    ),
    'digits', coalesce(
      nullif(customer_policy.policy_value::jsonb->>'serial_digits','')::integer,
      nullif(registry.policy_value::jsonb #>> '{types,customer,serial_digits}','')::integer,
      nullif(registry.policy_value::jsonb #>> '{types,customer,digits}','')::integer,
      4
    ),
    'serial_digits', coalesce(
      nullif(customer_policy.policy_value::jsonb->>'serial_digits','')::integer,
      nullif(registry.policy_value::jsonb #>> '{types,customer,serial_digits}','')::integer,
      nullif(registry.policy_value::jsonb #>> '{types,customer,digits}','')::integer,
      4
    ),
    'geo_digits', 8,
    'fields', jsonb_build_array(
      jsonb_build_object(
        'name', 'كود الدولة والمحافظة والحي/المركز والمنطقة بدون حروف',
        'digits', 8
      ),
      jsonb_build_object(
        'name', 'تسلسل العميل',
        'digits', coalesce(
          nullif(customer_policy.policy_value::jsonb->>'serial_digits','')::integer,
          nullif(registry.policy_value::jsonb #>> '{types,customer,serial_digits}','')::integer,
          nullif(registry.policy_value::jsonb #>> '{types,customer,digits}','')::integer,
          4
        )
      )
    )
  ),
  true
)::text,
updated_at = now()
FROM public.erp_program_policies customer_policy
WHERE registry.company_id = customer_policy.company_id
  AND registry.policy_key = 'code_generation_registry'
  AND customer_policy.policy_key = 'customer_code'
  AND left(registry.policy_value,1) = '{'
  AND left(customer_policy.policy_value,1) = '{';

-- New companies without a separate customer policy row still receive a
-- consistent four-digit customer serial definition in their central registry.
UPDATE public.erp_program_policies registry
SET policy_value = jsonb_set(
  registry.policy_value::jsonb,
  '{types,customer}',
  coalesce(registry.policy_value::jsonb #> '{types,customer}', '{}'::jsonb)
  || jsonb_build_object(
    'digits', coalesce(nullif(registry.policy_value::jsonb #>> '{types,customer,serial_digits}','')::integer,
                       nullif(registry.policy_value::jsonb #>> '{types,customer,digits}','')::integer,4),
    'serial_digits', coalesce(nullif(registry.policy_value::jsonb #>> '{types,customer,serial_digits}','')::integer,
                              nullif(registry.policy_value::jsonb #>> '{types,customer,digits}','')::integer,4),
    'geo_digits', 8,
    'fields', jsonb_build_array(
      jsonb_build_object('name','كود الدولة والمحافظة والحي/المركز والمنطقة بدون حروف','digits',8),
      jsonb_build_object(
        'name','تسلسل العميل',
        'digits',coalesce(nullif(registry.policy_value::jsonb #>> '{types,customer,serial_digits}','')::integer,
                          nullif(registry.policy_value::jsonb #>> '{types,customer,digits}','')::integer,4)
      )
    )
  ),
  true
)::text,
updated_at = now()
WHERE registry.policy_key = 'code_generation_registry'
  AND left(registry.policy_value,1) = '{'
  AND NOT EXISTS (
    SELECT 1 FROM public.erp_program_policies customer_policy
    WHERE customer_policy.company_id=registry.company_id
      AND customer_policy.policy_key='customer_code'
  );

COMMIT;
