-- Keep the activity branch/warehouse code policies distinct from company branches.
update public.erp_program_policies
set name_ar = case policy_key
  when 'code_type.workspace_branch' then 'فروع النشاطات'
  when 'code_type.workspace_warehouse' then 'مخازن النشاطات'
  else name_ar
end,
name_en = case policy_key
  when 'code_type.workspace_branch' then 'Activity branches'
  when 'code_type.workspace_warehouse' then 'Activity warehouses'
  else name_en
end,
updated_at = now()
where policy_key in ('code_type.workspace_branch','code_type.workspace_warehouse');
