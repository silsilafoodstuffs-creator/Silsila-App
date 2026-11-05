update public.erp_program_policies
set policy_value = jsonb_set(policy_value::jsonb, '{geo_prefix}', to_jsonb('Rig'::text), true)::text,
    updated_at = now()
where policy_key = 'code_generation_registry'
  and coalesce(policy_value::jsonb #>> '{geo_prefix}', '') <> 'Rig';
