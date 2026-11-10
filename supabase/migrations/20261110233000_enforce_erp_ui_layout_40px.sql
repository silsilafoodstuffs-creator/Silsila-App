UPDATE public.erp_program_policies
SET policy_value=jsonb_build_object(
  'row_height',40,
  'field_height',40,
  'column_spacing',5
)::text,
updated_at=now()
WHERE policy_key='ui_layout_standard';
