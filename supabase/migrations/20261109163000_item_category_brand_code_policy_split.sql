-- Final Silsila coding policies: global Cat hierarchy, Itm serial, Bra and Cus.
do $$
declare v_def text;
begin
  -- Category ranks are unique across all activities within one company.
  v_def := pg_get_functiondef('public.erp_item_categories_validate_tree_and_code()'::regprocedure);
  v_def := replace(v_def,
    $old$select id, parent_id, category_code, company_id, activity_code$old$,
    $new$select id, parent_id, category_code, company_id, activity_code, created_at$new$);
  v_def := replace(v_def,
    $old$and (c.category_code, c.id) <= (v_node.category_code, v_node.id);$old$,
    $new$and (c.created_at, c.id) <= (v_node.created_at, v_node.id);$new$);
  v_def := replace(v_def,
    $old$        and c.activity_code is not distinct from new.activity_code
        and c.parent_id is not distinct from v_node.parent_id$old$,
    $new$        and c.parent_id is not distinct from v_node.parent_id$new$);
  v_def := replace(v_def,
    $old$      and c.activity_code is not distinct from new.activity_code
      and c.parent_id is not distinct from new.parent_id;$old$,
    $new$      and c.parent_id is not distinct from new.parent_id;$new$);
  v_def := replace(v_def,
    $old$new.company_id::text || ':category:' || coalesce(new.activity_code, '') || ':' || coalesce(new.parent_id::text, 'root')$old$,
    $new$new.company_id::text || ':category:' || coalesce(new.parent_id::text, 'root')$new$);
  if position('pg_advisory_xact_lock' in v_def)=0 then
    v_def := replace(v_def,
      $old$    select count(*) + 1 into v_rank$old$,
      $new$    perform pg_advisory_xact_lock(hashtextextended(new.company_id::text || ':category:' || coalesce(new.parent_id::text, 'root'), 0));
    select count(*) + 1 into v_rank$new$);
  end if;
  if position('v_node.created_at' in v_def)=0
     or position('and c.activity_code is not distinct from new.activity_code' in v_def)>0
     or position('coalesce(new.activity_code' in v_def)>0 then
    raise exception 'Category code policy migration failed validation';
  end if;
  execute v_def;

  -- Item codes use the exact same global category path and a 3-digit serial.
  v_def := pg_get_functiondef('public.erp_assign_item_hierarchical_code()'::regprocedure);
  v_def := replace(v_def,$old$v_serial_digits integer := 2;$old$,$new$v_serial_digits integer := 3;$new$);
  v_def := replace(v_def,$old$v_serial_digits := coalesce(nullif(v_segments->>'serial', '')::integer, 2);$old$,$new$v_serial_digits := coalesce(nullif(v_segments->>'serial', '')::integer, 3);$new$);
  v_def := replace(v_def,$old$v_prefix text := 'itm';$old$,$new$v_prefix text := 'Itm';$new$);
  v_def := replace(v_def,$old$select id, parent_id, category_code into v_node$old$,$new$select id, parent_id, category_code, created_at into v_node$new$);
  v_def := replace(v_def,$old$and (c.category_code, c.id) <= (v_node.category_code, v_node.id);$old$,$new$and (c.created_at, c.id) <= (v_node.created_at, v_node.id);$new$);
  v_def := replace(v_def,
    $old$      and c.parent_id is not distinct from v_node.parent_id
      and c.activity_code is not distinct from (
        select activity_code from public.erp_item_categories where id = new.category_id
      )
      and (c.created_at, c.id) <= (v_node.created_at, v_node.id);$old$,
    $new$      and c.parent_id is not distinct from v_node.parent_id
      and (c.created_at, c.id) <= (v_node.created_at, v_node.id);$new$);
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
  if position('v_node.created_at' in v_def)=0
     or position('v_serial_digits <> 3' in v_def)=0
     or position('v_prefix <> ''Itm''' in v_def)=0
     or position('select activity_code from public.erp_item_categories where id = new.category_id' in v_def)>0 then
    raise exception 'Item code policy migration failed validation';
  end if;
  execute v_def;

  -- Customer codes are Cus + 8 geographic digits + a 2-digit serial.
  v_def := pg_get_functiondef('public.erp_assign_customer_geo_code()'::regprocedure);
  v_def := replace(v_def,'v_digits integer:=3;','v_digits integer:=2;');
  v_def := replace(v_def,'v_digits integer:=4;','v_digits integer:=2;');
  v_def := replace(v_def,'::integer,3);','::integer,2);');
  v_def := replace(v_def,'::integer,4);','::integer,2);');
  v_def := replace(v_def,'v_digits<>3','v_digits<>2');
  v_def := replace(v_def,'v_digits<>4','v_digits<>2');
  v_def := replace(v_def,'[0-9]{3}$','[0-9]{2}$');
  v_def := replace(v_def,'[0-9]{4}$','[0-9]{2}$');
  v_def := replace(v_def,'>=1000 then','>=100 then');
  v_def := replace(v_def,'>=10000 then','>=100 then');
  v_def := replace(v_def,'::text,3,','::text,2,');
  v_def := replace(v_def,'::text,4,','::text,2,');
  v_def := replace(v_def,'تسلسل (3 أرقام)','تسلسل (رقمين)');
  v_def := replace(v_def,'تسلسل (4 أرقام)','تسلسل (رقمين)');
  v_def := replace(v_def,'أرقام تسلسل العملاء الثلاثة','أرقام تسلسل العملاء المكونة من رقمين');
  v_def := replace(v_def,'أرقام تسلسل العملاء الأربعة','أرقام تسلسل العملاء المكونة من رقمين');
  if position('v_digits<>2' in v_def)=0 or position('[0-9]{2}$' in v_def)=0
     or position('::text,2,' in v_def)=0 then
    raise exception 'Customer code trigger migration failed validation';
  end if;
  execute v_def;

  v_def := pg_get_functiondef('public.erp_preview_next_customer_geo_code(uuid,uuid)'::regprocedure);
  v_def := replace(v_def,'v_digits integer:=3;','v_digits integer:=2;');
  v_def := replace(v_def,'v_digits integer:=4;','v_digits integer:=2;');
  v_def := replace(v_def,'::integer,3);','::integer,2);');
  v_def := replace(v_def,'::integer,4);','::integer,2);');
  v_def := replace(v_def,'v_digits<>3','v_digits<>2');
  v_def := replace(v_def,'v_digits<>4','v_digits<>2');
  v_def := replace(v_def,'[0-9]{3}$','[0-9]{2}$');
  v_def := replace(v_def,'[0-9]{4}$','[0-9]{2}$');
  v_def := replace(v_def,'>=1000 then','>=100 then');
  v_def := replace(v_def,'>=10000 then','>=100 then');
  v_def := replace(v_def,'::text,3,','::text,2,');
  v_def := replace(v_def,'::text,4,','::text,2,');
  v_def := replace(v_def,'تسلسل (3 أرقام)','تسلسل (رقمين)');
  v_def := replace(v_def,'تسلسل (4 أرقام)','تسلسل (رقمين)');
  v_def := replace(v_def,'أرقام تسلسل العملاء الثلاثة','أرقام تسلسل العملاء المكونة من رقمين');
  v_def := replace(v_def,'أرقام تسلسل العملاء الأربعة','أرقام تسلسل العملاء المكونة من رقمين');
  if position('v_digits<>2' in v_def)=0 or position('[0-9]{2}$' in v_def)=0
     or position('::text,2,' in v_def)=0 then
    raise exception 'Customer code preview migration failed validation';
  end if;
  execute v_def;
end $$;

-- Preserve all categories and their parent links; ranks are global per company at each level.
with recursive category_tree as (
  select c.id,c.company_id,c.parent_id,c.created_at,
         'Cat'||lpad(row_number() over(partition by c.company_id order by c.created_at,c.id)::text,2,'0') as generated_code
  from public.erp_item_categories c where c.parent_id is null
  union all
  select c.id,c.company_id,c.parent_id,c.created_at,
         p.generated_code||lpad((
           select count(*)::text from public.erp_item_categories sibling
           where sibling.company_id=c.company_id
             and sibling.parent_id is not distinct from c.parent_id
             and (sibling.created_at,sibling.id)<=(c.created_at,c.id)
         ),2,'0')
  from public.erp_item_categories c join category_tree p on p.id=c.parent_id
)
update public.erp_item_categories c
set category_code=t.generated_code,updated_at=now()
from category_tree t where c.id=t.id and c.category_code is distinct from t.generated_code;

update public.erp_program_policies
set category='سياسات الأكواد',updated_at=now()
where policy_key like 'geo_code.%';

-- Align the registry with the exact customer, category, brand and item formats.
update public.erp_program_policies p
set policy_value=jsonb_set(
  jsonb_set(
    jsonb_set(
      jsonb_set(
        jsonb_set(
          jsonb_set(
            jsonb_set(
              jsonb_set(p.policy_value::jsonb,'{types,customer}',
                '{"prefix":"Cus","digits":2,"automatic":true,"composite":true,"required":true,"apply_to_all":true,"geo_digits":8,"serial_digits":2,"fields":[{"name":"كود الدولة والمحافظة والحي/المركز والمنطقة بدون حروف","digits":8},{"name":"تسلسل العميل","digits":2}]}'::jsonb,true),
              '{types,category}',
                '{"prefix":"Cat","digits":6,"automatic":true,"composite":true,"fields":[{"name":"فئة رئيسية","digits":2},{"name":"فئة فرعية","digits":2},{"name":"فئة ثانوية","digits":2}]}'::jsonb,true),
            '{types,brand}','{"prefix":"Bra","digits":3,"automatic":true,"composite":false}'::jsonb,true),
          '{item_prefix}','"Itm"'::jsonb,true),
        '{item_segments}','{"main":2,"sub":2,"secondary":2,"serial":3}'::jsonb,true),
      '{category_prefix}','"Cat"'::jsonb,true),
    '{category_segments}','{"main":2,"sub":2,"secondary":2}'::jsonb,true),
  '{brand_prefix}','"Bra"'::jsonb,true
)::text,
updated_at=now()
where p.policy_key='code_generation_registry' and left(p.policy_value,1)='{';

update public.erp_program_policies p
set policy_value=jsonb_set(p.policy_value::jsonb,'{brand_digits}','3'::jsonb,true)::text,
updated_at=now()
where p.policy_key='code_generation_registry' and left(p.policy_value,1)='{';

insert into public.erp_program_policies
(company_id,policy_key,category,name_ar,name_en,is_enabled,apply_to_all,user_ids,policy_value,policy_code)
select c.company_id,p.policy_key,'سياسات الأكواد',p.name_ar,p.name_en,true,true,'[]'::jsonb,p.policy_value,p.policy_code
from (select distinct company_id from public.erp_program_policies) c
cross join (values
 ('category_code.main','سياسة تكويد فئات أصناف رئيسية','Main item category coding policy','{"prefix":"Cat","digits":2,"parent_digits":0}'::text,'Pol058'),
 ('category_code.sub','سياسة تكويد فئات أصناف فرعية','Sub item category coding policy','{"prefix":"Cat","digits":2,"parent_digits":2}'::text,'Pol059'),
 ('category_code.secondary','سياسة تكويد فئات أصناف ثانوية','Secondary item category coding policy','{"prefix":"Cat","digits":2,"parent_digits":4}'::text,'Pol060'),
 ('brand_code','سياسة تكويد البراند','Brand coding policy','{"prefix":"Bra","digits":3,"parent_digits":0}'::text,'Pol061'),
 ('item_code','سياسة تكويد الأصناف','Item coding policy','{"prefix":"Itm","category_digits":6,"serial_digits":3}'::text,'Pol062'),
 ('customer_code','سياسة تكويد العملاء','Customer coding policy','{"prefix":"Cus","geo_digits":8,"serial_digits":2,"required":true,"apply_to_all":true}'::text,'Pol063')
) p(policy_key,name_ar,name_en,policy_value,policy_code)
on conflict(company_id,policy_key) do update
set category=excluded.category,name_ar=excluded.name_ar,name_en=excluded.name_en,
    is_enabled=true,apply_to_all=true,user_ids='[]'::jsonb,
    policy_value=excluded.policy_value,policy_code=excluded.policy_code;
