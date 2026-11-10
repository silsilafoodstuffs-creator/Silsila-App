INSERT INTO public.erp_program_policies
  (company_id, policy_key, category, name_ar, name_en, is_enabled, apply_to_all, user_ids, policy_value, policy_code)
SELECT c.company_id, v.policy_key, 'تكويدية', v.name_ar, v.name_en, true, true, '[]'::jsonb,
       jsonb_build_object('prefix',v.prefix,'digits',v.digits)::text, v.policy_code
FROM (
  SELECT DISTINCT company_id
  FROM public.erp_program_policies
  WHERE policy_key='code_generation_registry' OR policy_key LIKE 'code_type.%'
) c
CROSS JOIN (VALUES
  ('code_type.construction_material_movement','حركات مواد المشروعات','Construction material movements','Cmm',5,'Pol146'),
  ('code_type.workspace_item_link','ربط الأصناف بالنشاط','Workspace item links','Wil',5,'Pol147'),
  ('code_type.business_suite_record','سجلات إدارة الأنشطة','Business suite records','Bsr',5,'Pol148')
) AS v(policy_key,name_ar,name_en,prefix,digits,policy_code)
ON CONFLICT (company_id, policy_key) DO NOTHING;