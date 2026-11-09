-- Add separately configurable geographic coding policies for every company.
-- The existing BEFORE trigger assigns the next Pol### identifier per company.
insert into public.erp_program_policies
  (company_id, policy_key, category, name_ar, name_en, is_enabled, apply_to_all, user_ids, policy_value)
select c.company_id, 'geo_code.country', 'جغرافية', 'سياسة تكويد دول', 'Country coding policy',
       true, true, '[]'::jsonb, '{"prefix":"Con","digits":2,"parent_digits":0}'
from (select distinct company_id from public.erp_program_policies) c
on conflict (company_id, policy_key) do update set
  category=excluded.category, name_ar=excluded.name_ar, name_en=excluded.name_en,
  is_enabled=true, apply_to_all=true, user_ids='[]'::jsonb,
  policy_value=excluded.policy_value;

insert into public.erp_program_policies
  (company_id, policy_key, category, name_ar, name_en, is_enabled, apply_to_all, user_ids, policy_value)
select c.company_id, 'geo_code.governorate', 'جغرافية', 'سياسة تكويد محافظات', 'Governorate coding policy',
       true, true, '[]'::jsonb, '{"prefix":"Gov","digits":2,"parent_digits":2}'
from (select distinct company_id from public.erp_program_policies) c
on conflict (company_id, policy_key) do update set
  category=excluded.category, name_ar=excluded.name_ar, name_en=excluded.name_en,
  is_enabled=true, apply_to_all=true, user_ids='[]'::jsonb,
  policy_value=excluded.policy_value;

insert into public.erp_program_policies
  (company_id, policy_key, category, name_ar, name_en, is_enabled, apply_to_all, user_ids, policy_value)
select c.company_id, 'geo_code.district', 'جغرافية', 'سياسة تكويد أحياء/مراكز', 'District/center coding policy',
       true, true, '[]'::jsonb, '{"prefix":"Dis","digits":2,"parent_digits":4}'
from (select distinct company_id from public.erp_program_policies) c
on conflict (company_id, policy_key) do update set
  category=excluded.category, name_ar=excluded.name_ar, name_en=excluded.name_en,
  is_enabled=true, apply_to_all=true, user_ids='[]'::jsonb,
  policy_value=excluded.policy_value;

insert into public.erp_program_policies
  (company_id, policy_key, category, name_ar, name_en, is_enabled, apply_to_all, user_ids, policy_value)
select c.company_id, 'geo_code.area', 'جغرافية', 'سياسة تكويد مناطق/قرى', 'Area/village coding policy',
       true, true, '[]'::jsonb, '{"prefix":"Rig","digits":2,"parent_digits":6}'
from (select distinct company_id from public.erp_program_policies) c
on conflict (company_id, policy_key) do update set
  category=excluded.category, name_ar=excluded.name_ar, name_en=excluded.name_en,
  is_enabled=true, apply_to_all=true, user_ids='[]'::jsonb,
  policy_value=excluded.policy_value;
