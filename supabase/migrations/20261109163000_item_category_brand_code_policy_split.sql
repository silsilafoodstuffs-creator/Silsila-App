-- Final Silsila coding policies: global Cat hierarchy, Itm serial, Bra and Cus.
do $$
declare v_def text;
begin
  v_def := pg_get_functiondef('public.erp_item_categories_validate_tree_and_code()'::regprocedure);
  v_def := replace(v_def,
    $old$        and c.activity_code is not distinct from new.activity_code
        and c.parent_id is not distinct from v_node.parent_id$old$,
    $new$        and c.parent_id is not distinct from v_node.parent_id$new$);
  v_def := replace(v_def,
    $old$    perform pg_advisory_xact_lock(hashtextextended(new.company_id::text || ':category:' || coalesce(new.activity_code, '') || ':' || coalesce(new.parent_id::text, 'root'), 0));$old$,
    $new$    perform pg_advisory_xact_lock(hashtextextended(new.company_id::text || ':category:' || coalesce(new.parent_id::text, 'root'), 0));$new$);
  v_def := replace(v_def,
    $old$    where c.company_id = new.company_id
      and c.activity_code is not distinct from new.activity_code
      and c.parent_id is not distinct from new.parent_id;$old$,
    $new$    where c.company_id = new.company_id
      and c.parent_id is not distinct from new.parent_id;$new$);
  if position('and c.activity_code is not distinct from new.activity_code' in v_def)>0
     or position('coalesce(new.activity_code' in v_def)>0
     or position('v_node.created_at' in v_def)=0 then
    raise exception 'Category code policy migration failed validation';
  end if;
  execute v_def;

  v_def := pg_get_functiondef('public.erp_assign_item_hierarchical_code()'::regprocedure);
  v_def := replace(v_def,
    $old$      and c.parent_id is not distinct from v_node.parent_id
      and c.activity_code is not distinct from (
        select activity_code from public.erp_item_categories where id = new.category_id
      )
      and (c.created_at, c.id) <= (v_node.created_at, v_node.id);$old$,
    $new$      and c.parent_id is not distinct from v_node.parent_id
      and (c.created_at, c.id) <= (v_node.created_at, v_node.id);$new$);
  v_def := replace(v_def,$old$v_prefix text := 'itm';$old$,$new$v_prefix text := 'Itm';$new$);
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
  if position('select activity_code from public.erp_item_categories where id = new.category_id' in v_def)>0
     or position('v_prefix <> ''Itm''' in v_def)=0
     or position('v_serial_digits <> 3' in v_def)=0 then
    raise exception 'Item code policy migration failed validation';
  end if;
  execute v_def;

  v_def := pg_get_functiondef('public.erp_assign_customer_geo_code()'::regprocedure);
  v_def := replace(v_def,$old$v_digits integer:=4;$old$,$new$v_digits integer:=2;$new$);
  v_def := replace(v_def,$old$::integer,4);$old$,$new$::integer,2);$new$);
  v_def := replace(v_def,$old$if v_prefix<>'Cus' or v_digits<>4 then$old$,$new$if v_prefix<>'Cus' or v_digits<>2 then$new$);
  v_def := replace(v_def,$old$'[0-9]{4}$')$old$,$new$'[0-9]{2}$')$new$);
  v_def := replace(v_def,$old$>=10000 then$old$,$new$>=100 then$new$);
  v_def := replace(v_def,$old$lpad((coalesce(v_max,0)+1)::text,4,'0')$old$,$new$lpad((coalesce(v_max,0)+1)::text,2,'0')$new$);
  v_def := replace(v_def,$old$تسلسل (4 أرقام)$old$,$new$تسلسل (رقمين)$new$);
  if position('v_digits<>2' in v_def)=0 or position('[0-9]{2}

  v_def := pg_get_functiondef('public.erp_preview_next_customer_geo_code(uuid,uuid)'::regprocedure);
  v_def := replace(v_def,$old$v_digits integer:=4;$old$,$new$v_digits integer:=2;$new$);
  v_def := replace(v_def,$old$::integer,4);$old$,$new$::integer,2);$new$);
  v_def := replace(v_def,$old$if v_prefix<>'Cus' or v_digits<>4 then$old$,$new$if v_prefix<>'Cus' or v_digits<>2 then$new$);
  v_def := replace(v_def,$old$'[0-9]{4}$')$old$,$new$'[0-9]{2}$')$new$);
  v_def := replace(v_def,$old$>=10000 then$old$,$new$>=100 then$new$);
  v_def := replace(v_def,$old$lpad((coalesce(v_max,0)+1)::text,4,'0')$old$,$new$lpad((coalesce(v_max,0)+1)::text,2,'0')$new$);
  v_def := replace(v_def,$old$تسلسل (4 أرقام)$old$,$new$تسلسل (رقمين)$new$);
  if position('v_digits<>2' in v_def)=0 or position('[0-9]{2}
end $$;

-- Preserve every category record and its parent relationship while replacing legacy ACT codes.
with recursive ranked as (
  select id,company_id,parent_id,
         row_number() over(partition by company_id,parent_id order by created_at,id) as rank
  from public.erp_item_categories
), tree as (
  select r.id,r.company_id,r.parent_id,
         'Cat'||lpad(r.rank::text,2,'0') as new_code
  from ranked r where r.parent_id is null
  union all
  select c.id,c.company_id,c.parent_id,
         p.new_code||lpad(c.rank::text,2,'0')
  from ranked c join tree p on p.id=c.parent_id
)
update public.erp_item_categories c
set category_code=t.new_code
from tree t
where c.id=t.id and c.category_code is distinct from t.new_code;

update public.erp_program_policies
set category='سياسات الأكواد',updated_at=now()
where policy_key like 'geo_code.%';

update public.erp_program_policies p
set policy_value=jsonb_set(
  jsonb_set(
    jsonb_set(p.policy_value::jsonb,'{types,customer,digits}','2'::jsonb,true),
    '{types,customer,serial_digits}','2'::jsonb,true
  ),
  '{types,customer,fields,1,digits}','2'::jsonb,true
)::text,
updated_at=now()
where p.policy_key='code_generation_registry' and left(p.policy_value,1)='{';

update public.erp_program_policies p
set policy_value=jsonb_set(p.policy_value::jsonb,'{customer_code,serial_digits}','2'::jsonb,true)::text,
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
 in v_def)=0 then
    raise exception 'Customer code trigger migration failed validation';
  end if;
  v_def := replace(v_def,$old$انتهت أرقام تسلسل العملاء الأربعة داخل هذه المنطقة$old$,$new$انتهت أرقام تسلسل العملاء المكونة من رقمين داخل هذه المنطقة$new$);
  execute v_def;

  v_def := pg_get_functiondef('public.erp_preview_next_customer_geo_code(uuid,uuid)'::regprocedure);
  v_def := replace(v_def,$old$v_digits integer:=4;$old$,$new$v_digits integer:=2;$new$);
  v_def := replace(v_def,$old$::integer,4);$old$,$new$::integer,2);$new$);
  v_def := replace(v_def,$old$if v_prefix<>'Cus' or v_digits<>4 then$old$,$new$if v_prefix<>'Cus' or v_digits<>2 then$new$);
  v_def := replace(v_def,$old$'[0-9]{4}$')$old$,$new$'[0-9]{2}$')$new$);
  v_def := replace(v_def,$old$>=10000 then$old$,$new$>=100 then$new$);
  v_def := replace(v_def,$old$lpad((coalesce(v_max,0)+1)::text,4,'0')$old$,$new$lpad((coalesce(v_max,0)+1)::text,2,'0')$new$);
  v_def := replace(v_def,$old$تسلسل (4 أرقام)$old$,$new$تسلسل (رقمين)$new$);
  if position('v_digits<>2' in v_def)=0 or position('[0-9]{2}$' in v_def)=0 then
    raise exception 'Customer code preview migration failed validation';
  end if;
  execute v_def;
end $$;

-- Preserve every category record and its parent relationship while replacing legacy ACT codes.
with recursive ranked as (
  select id,company_id,parent_id,
         row_number() over(partition by company_id,parent_id order by created_at,id) as rank
  from public.erp_item_categories
), tree as (
  select r.id,r.company_id,r.parent_id,
         'Cat'||lpad(r.rank::text,2,'0') as new_code
  from ranked r where r.parent_id is null
  union all
  select c.id,c.company_id,c.parent_id,
         p.new_code||lpad(c.rank::text,2,'0')
  from ranked c join tree p on p.id=c.parent_id
)
update public.erp_item_categories c
set category_code=t.new_code
from tree t
where c.id=t.id and c.category_code is distinct from t.new_code;

update public.erp_program_policies
set category='سياسات الأكواد',updated_at=now()
where policy_key like 'geo_code.%';

update public.erp_program_policies p
set policy_value=jsonb_set(
  jsonb_set(
    jsonb_set(p.policy_value::jsonb,'{types,customer,digits}','2'::jsonb,true),
    '{types,customer,serial_digits}','2'::jsonb,true
  ),
  '{types,customer,fields,1,digits}','2'::jsonb,true
)::text,
updated_at=now()
where p.policy_key='code_generation_registry' and left(p.policy_value,1)='{';

update public.erp_program_policies p
set policy_value=jsonb_set(p.policy_value::jsonb,'{customer_code,serial_digits}','2'::jsonb,true)::text,
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
 in v_def)=0 then
    raise exception 'Customer code preview migration failed validation';
  end if;
  v_def := replace(v_def,$old$انتهت أرقام تسلسل العملاء الأربعة داخل هذه المنطقة$old$,$new$انتهت أرقام تسلسل العملاء المكونة من رقمين داخل هذه المنطقة$new$);
  execute v_def;
end $$;

-- Preserve every category record and its parent relationship while replacing legacy ACT codes.
with recursive ranked as (
  select id,company_id,parent_id,
         row_number() over(partition by company_id,parent_id order by created_at,id) as rank
  from public.erp_item_categories
), tree as (
  select r.id,r.company_id,r.parent_id,
         'Cat'||lpad(r.rank::text,2,'0') as new_code
  from ranked r where r.parent_id is null
  union all
  select c.id,c.company_id,c.parent_id,
         p.new_code||lpad(c.rank::text,2,'0')
  from ranked c join tree p on p.id=c.parent_id
)
update public.erp_item_categories c
set category_code=t.new_code
from tree t
where c.id=t.id and c.category_code is distinct from t.new_code;

update public.erp_program_policies
set category='سياسات الأكواد',updated_at=now()
where policy_key like 'geo_code.%';

update public.erp_program_policies p
set policy_value=jsonb_set(
  jsonb_set(
    jsonb_set(p.policy_value::jsonb,'{types,customer,digits}','2'::jsonb,true),
    '{types,customer,serial_digits}','2'::jsonb,true
  ),
  '{types,customer,fields,1,digits}','2'::jsonb,true
)::text,
updated_at=now()
where p.policy_key='code_generation_registry' and left(p.policy_value,1)='{';

update public.erp_program_policies p
set policy_value=jsonb_set(p.policy_value::jsonb,'{customer_code,serial_digits}','2'::jsonb,true)::text,
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
 in v_def)=0 then
    raise exception 'Customer code trigger migration failed validation';
  end if;
  v_def := replace(v_def,$old$انتهت أرقام تسلسل العملاء الأربعة داخل هذه المنطقة$old$,$new$انتهت أرقام تسلسل العملاء المكونة من رقمين داخل هذه المنطقة$new$);
  execute v_def;

  v_def := pg_get_functiondef('public.erp_preview_next_customer_geo_code(uuid,uuid)'::regprocedure);
  v_def := replace(v_def,$old$v_digits integer:=4;$old$,$new$v_digits integer:=2;$new$);
  v_def := replace(v_def,$old$::integer,4);$old$,$new$::integer,2);$new$);
  v_def := replace(v_def,$old$if v_prefix<>'Cus' or v_digits<>4 then$old$,$new$if v_prefix<>'Cus' or v_digits<>2 then$new$);
  v_def := replace(v_def,$old$'[0-9]{4}$')$old$,$new$'[0-9]{2}$')$new$);
  v_def := replace(v_def,$old$>=10000 then$old$,$new$>=100 then$new$);
  v_def := replace(v_def,$old$lpad((coalesce(v_max,0)+1)::text,4,'0')$old$,$new$lpad((coalesce(v_max,0)+1)::text,2,'0')$new$);
  v_def := replace(v_def,$old$تسلسل (4 أرقام)$old$,$new$تسلسل (رقمين)$new$);
  if position('v_digits<>2' in v_def)=0 or position('[0-9]{2}$' in v_def)=0 then
    raise exception 'Customer code preview migration failed validation';
  end if;
  execute v_def;
end $$;

-- Preserve every category record and its parent relationship while replacing legacy ACT codes.
with recursive ranked as (
  select id,company_id,parent_id,
         row_number() over(partition by company_id,parent_id order by created_at,id) as rank
  from public.erp_item_categories
), tree as (
  select r.id,r.company_id,r.parent_id,
         'Cat'||lpad(r.rank::text,2,'0') as new_code
  from ranked r where r.parent_id is null
  union all
  select c.id,c.company_id,c.parent_id,
         p.new_code||lpad(c.rank::text,2,'0')
  from ranked c join tree p on p.id=c.parent_id
)
update public.erp_item_categories c
set category_code=t.new_code
from tree t
where c.id=t.id and c.category_code is distinct from t.new_code;

update public.erp_program_policies
set category='سياسات الأكواد',updated_at=now()
where policy_key like 'geo_code.%';

update public.erp_program_policies p
set policy_value=jsonb_set(
  jsonb_set(
    jsonb_set(p.policy_value::jsonb,'{types,customer,digits}','2'::jsonb,true),
    '{types,customer,serial_digits}','2'::jsonb,true
  ),
  '{types,customer,fields,1,digits}','2'::jsonb,true
)::text,
updated_at=now()
where p.policy_key='code_generation_registry' and left(p.policy_value,1)='{';

update public.erp_program_policies p
set policy_value=jsonb_set(p.policy_value::jsonb,'{customer_code,serial_digits}','2'::jsonb,true)::text,
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
