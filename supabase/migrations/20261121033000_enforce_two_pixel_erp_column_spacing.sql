-- Enforce the approved project-wide 2px gap between adjacent ERP table columns.
-- Preserve the configured row and field heights while normalizing every company policy.
DO $$
DECLARE
  policy_row record;
  dimensions jsonb;
BEGIN
  FOR policy_row IN
    SELECT company_id, policy_value
    FROM public.erp_program_policies
    WHERE policy_key = 'ui_layout_standard'
  LOOP
    BEGIN
      dimensions := COALESCE(NULLIF(policy_row.policy_value, '')::jsonb, '{}'::jsonb);
      IF jsonb_typeof(dimensions) <> 'object' THEN
        dimensions := '{}'::jsonb;
      END IF;
    EXCEPTION WHEN others THEN
      dimensions := '{}'::jsonb;
    END;

    dimensions := jsonb_set(
      dimensions,
      '{row_height}',
      COALESCE(dimensions->'row_height', '40'::jsonb),
      true
    );
    dimensions := jsonb_set(
      dimensions,
      '{field_height}',
      COALESCE(dimensions->'field_height', '40'::jsonb),
      true
    );
    dimensions := jsonb_set(dimensions, '{column_spacing}', '2'::jsonb, true);

    UPDATE public.erp_program_policies
    SET policy_value = dimensions::text,
        updated_at = now()
    WHERE company_id = policy_row.company_id
      AND policy_key = 'ui_layout_standard';
  END LOOP;
END $$;
