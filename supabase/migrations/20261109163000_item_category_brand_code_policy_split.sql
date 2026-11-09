-- Rename the geographic-policy group and define independent hierarchical Cat, Bra and Itm formats.
do $$
declare v_def text;
begin
  v_def := pg_get_functiondef('public.erp_item_categories_validate_tree_and_code()'::regprocedure);
  v_def := replace(v_def,
    $old$select id, parent_id, category_code, company_id, activity_code$old$,
    $new$select id, parent_id, category_code, company_id, activity_code, created_at$new$);
  v_def := replace(v_def,
    $old$and (c.category_code, c.id) <= (v_node.category_code, v_node.id);$old$,
    $new$and (c.created_at, c.id) <= (v_node.created_at, v_node.id);$new$);
  v_def := replace(v_def,
    $old$    select count(*) + 1 into v_rank$old$,
    $new$    perform pg_advisory_xact_lock(hashtextextended(new.company_id::text || ':category:' || coalesce(new.activity_code, '') || ':' || coalesce(new.parent_id::text, 'root'), 0));
    select count(*) + 1 into v_rank$new$);
  execute v_def;

  v_def := pg_get_functiondef('public.erp_assign_item_hierarchical_code()'::regprocedure);
  v_def := replace(v_def, $old$v_serial_digits integer := 2;$old$, $new$v_serial_digits integer := 3;$new$);
  v_def := replace(v_def,
    $old$v_serial_digits := coalesce(nullif(v_segments->>'serial', '')::integer, 2);$old$,
    $new$v_serial_digits := coalesce(nullif(v_segments->>'serial', '')::integer, 3);$new$);
  v_def := replace(v_def,
    $old$select id, parent_id, category_code into v_node$old$,
    $new$select id, parent_id, category_code, created_at into v_node$new$);
  v_def := replace(v_def,
    $old$and (c.category_code, c.id) <= (v_node.category_code, v_node.id);$old$,
    $new$and (c.created_at, c.id) <= (v_node.created_at, v_node.id);$new$);
  v_def := replace(v_def,
    $old$  if v_main_digits not between 1 and 4
     or v_sub_digits not between 1 and 4
     or v_secondary_digits not between 1 and 4
     or v_serial_digits not between 1 and 8 then
    raise exception 'أطوال خانات كود الأصناف غير صحيحة';
  end if;$old$,
    $new$  if v_prefix <> 'Itm' or v_main_digits <> 2 or v_sub_digits <> 2
     or v_secondary_digits <> 2 or v_serial_digits <> 3 then
    raise exception 'سياسة كود الصنف ثابتة على Itm + 2 + 2 + 2 + 3 أرقام';
  end if;$new$);
  execute v_def;
end $$;

update public.erp_program_policies
set category = 'سياسات الأكواد', updated_at = now()
where policy_key like 'geo_code.%';

insert into public.erp_program_policies
(company_id,policy_key,category,name_ar,name_en,is_enabled,apply_to_all,user_ids,policy_value)
select c.company_id, p.policy_key, 'سياسات الأكواد', p.name_ar, p.name_en, true, true, '[]'::jsonb, p.policy_value
from (select distinct company_id from public.erp_program_policies) c
cross join (values
 ('category_code.main','سياسة تكويد فئات أصناف رئيسية','Main item category coding policy','{"prefix":"Cat","digits":2,"parent_digits":0}'::text),
 ('category_code.sub','سياسة تكويد فئات أصناف فرعية','Sub item category coding policy','{"prefix":"Cat","digits":2,"parent_digits":2}'::text),
 ('category_code.secondary','سياسة تكويد فئات أصناف ثانوية','Secondary item category coding policy','{"prefix":"Cat","digits":2,"parent_digits":4}'::text),
 ('brand_code','سياسة تكويد البراند','Brand coding policy','{"prefix":"Bra","digits":3,"parent_digits":0}'::text),
 ('item_code','سياسة تكويد الأصناف','Item coding policy','{"prefix":"Itm","category_digits":6,"serial_digits":3}'::text)
) as p(policy_key,name_ar,name_en,policy_value)
on conflict (company_id,policy_key) do update
set category = excluded.category,
    name_ar = excluded.name_ar,
    name_en = excluded.name_en,
    is_enabled = true,
    apply_to_all = true,
    user_ids = '[]'::jsonb,
    policy_value = excluded.policy_value;

update public.erp_program_policies p
set policy_value = jsonb_set(
  jsonb_set(
    case when left(p.policy_value,1)='{' then p.policy_value::jsonb else '{}'::jsonb end,
    '{item_prefix}','"Itm"'::jsonb,true
  ),
  '{item_segments}',
  '{"main":2,"sub":2,"secondary":2,"serial":3}'::jsonb,true
)::text,
updated_at = now()
where p.policy_key='code_generation_registry';
