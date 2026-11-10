BEGIN;

-- Match policy metadata to the formats already issued in this company.
-- Existing identifiers are intentionally preserved; this changes only the
-- next-code policy values and their central registry mirrors.
UPDATE public.erp_program_policies p
SET policy_value = coalesce(p.policy_value::jsonb, '{}'::jsonb)
  || jsonb_build_object('prefix', v.prefix, 'digits', v.digits)::jsonb,
    updated_at = now()
FROM (VALUES
  ('code_type.payment_method', 'PAY', 4),
  ('code_type.unit', 'UNT', 4),
  ('code_type.shift', 'Shf', 5),
  ('code_type.permission_template', 'Tpl', 5),
  ('code_type.user_classification', 'Cls', 5)
) AS v(policy_key, prefix, digits)
WHERE p.policy_key = v.policy_key
  AND left(p.policy_value,1) = '{';

WITH overrides AS (
  SELECT
    company_id,
    jsonb_object_agg(
      substr(policy_key, 11),
      jsonb_build_object(
        'prefix', policy_value::jsonb->>'prefix',
        'digits', (policy_value::jsonb->>'digits')::integer
      )
    ) AS types
  FROM public.erp_program_policies
  WHERE policy_key IN (
    'code_type.payment_method',
    'code_type.unit',
    'code_type.shift',
    'code_type.permission_template',
    'code_type.user_classification'
  )
  GROUP BY company_id
)
UPDATE public.erp_program_policies registry
SET policy_value = jsonb_set(
  registry.policy_value::jsonb,
  '{types}',
  coalesce(registry.policy_value::jsonb->'types','{}'::jsonb) || overrides.types,
  true
)::text,
updated_at = now()
FROM overrides
WHERE registry.company_id = overrides.company_id
  AND registry.policy_key = 'code_generation_registry'
  AND left(registry.policy_value,1) = '{';

DO $verify$
DECLARE
  bad_count integer;
BEGIN
  SELECT count(*) INTO bad_count
  FROM public.erp_program_policies p
  JOIN public.erp_program_policies r
    ON r.company_id=p.company_id AND r.policy_key='code_generation_registry'
  WHERE p.policy_key IN (
    'code_type.payment_method',
    'code_type.unit',
    'code_type.shift',
    'code_type.permission_template',
    'code_type.user_classification'
  )
  AND (
    p.policy_value::jsonb->>'prefix' IS DISTINCT FROM
      r.policy_value::jsonb #>> ARRAY['types',substr(p.policy_key,11),'prefix']
    OR p.policy_value::jsonb->>'digits' IS DISTINCT FROM
      r.policy_value::jsonb #>> ARRAY['types',substr(p.policy_key,11),'digits']
  );
  IF bad_count > 0 THEN
    RAISE EXCEPTION 'Central code policy registry remains inconsistent for % rows', bad_count;
  END IF;
END;
$verify$;

COMMIT;
