-- Central, company-scoped ERP code generation.
-- Apply after the existing ERP schema, HR schema and user administration migrations.
begin;

create or replace function public.erp_code_policy_config(p_company_id uuid, p_key text, p_default_prefix text, p_default_digits integer)
returns table(prefix text, digits integer)
language plpgsql stable security definer set search_path=public as $$
declare v jsonb; v_cfg jsonb;
begin
  select case when policy_value ~ '^\\s*\\{' then policy_value::jsonb else '{}'::jsonb end into v
  from public.erp_program_policies
  where company_id=p_company_id and policy_key='code_generation_registry'
  limit 1;
  v_cfg := coalesce(v->'types'->p_key, '{}'::jsonb);
  prefix := coalesce(nullif(v_cfg->>'prefix',''), p_default_prefix);
  digits := coalesce(nullif(v_cfg->>'digits','')::integer, p_default_digits);
  if prefix !~ '^[A-Za-z]{3}$' or digits < 1 or digits > 12 then
    raise exception 'إعدادات التكويد غير صحيحة للنوع %', p_key;
  end if;
  return next;
end;
$$;

create or replace function public.erp_assign_central_code()
returns trigger
language plpgsql security definer set search_path=public as $$
declare
  v_company uuid;
  v_key text;
  v_column text;
  v_prefix text;
  v_digits integer;
  v_kind text;
  v_max bigint;
  v_code text;
  v_lock text;
begin
  v_company := (to_jsonb(new)->>'company_id')::uuid;
  if v_company is null then raise exception 'company_id مطلوب لتوليد الكود'; end if;

  case tg_table_name
    when 'erp_employees' then v_key:='employee'; v_column:='employee_code';
    when 'erp_item_categories' then v_key:='category'; v_column:='category_code';
    when 'erp_item_categories' then v_key:='category'; v_column:='category_code';
    when 'erp_users' then v_key:='user'; v_column:='user_code';
    when 'erp_branches' then v_key:='branch'; v_column:='branch_code';
    when 'erp_warehouses' then v_key:='warehouse'; v_column:='warehouse_code';
    when 'erp_accounts' then v_key:='account'; v_column:='account_code';
    when 'erp_cashboxes' then v_key:='cashbox'; v_column:='cashbox_code';
    when 'erp_parties' then
      v_kind := coalesce(to_jsonb(new)->>'party_kind','supplier');
      v_key := case when v_kind='customer' then 'customer' else 'supplier' end;
      v_column:='party_code';
    when 'erp_hr_departments' then v_key:='department'; v_column:='department_code';
    when 'erp_hr_jobs' then v_key:='job'; v_column:='job_code';
    when 'erp_hr_work_locations' then v_key:='work_location'; v_column:='location_code';
    when 'erp_hr_job_grades' then v_key:='grade'; v_column:='grade_code';
    when 'erp_payroll_runs' then v_key:='payroll_run'; v_column:='run_code';
    else raise exception 'نوع سجل غير مدعوم في التكويد المركزي: %', tg_table_name;
  end case;

  if nullif(to_jsonb(new)->>v_column,'') is not null then return new; end if;

  select c.prefix,c.digits into v_prefix,v_digits
  from public.erp_code_policy_config(v_company,v_key,
    case v_key
      when 'employee' then 'Emp' when 'user' then 'Usr'
      when 'branch' then 'Brn' when 'warehouse' then 'Whs'
      when 'account' then 'Acc' when 'cashbox' then 'Csh'
      when 'supplier' then 'Sup' when 'customer' then 'Cus'
      when 'department' then 'Dpt' when 'job' then 'Job'
      when 'work_location' then 'Loc' when 'category' then 'Cat' when 'grade' then 'Grd' when 'payroll_run' then 'Pay' else 'Gen' end, 5) c;

  v_lock := v_company::text||':'||tg_table_name||':'||v_prefix;
  perform pg_advisory_xact_lock(hashtextextended(v_lock,0));

  if tg_table_name='erp_parties' then
    execute format('select coalesce(max(nullif(substring(%I from %L), '''')::bigint),0) from public.%I where company_id=$1 and party_kind=$2 and %I ~ $3',
      v_column, '^'||v_prefix||'([0-9]+)$', tg_table_name, v_column)
      into v_max using v_company,v_kind,'^'||v_prefix||'[0-9]+$';
  else
    execute format('select coalesce(max(nullif(substring(%I from %L), '''')::bigint),0) from public.%I where company_id=$1 and %I ~ $2',
      v_column, '^'||v_prefix||'([0-9]+)$', tg_table_name, v_column)
      into v_max using v_company,'^'||v_prefix||'[0-9]+$';
  end if;

  if coalesce(v_max,0)+1 >= power(10::numeric,v_digits) then raise exception 'انتهت خانات الكود للنوع %؛ زد عدد الخانات من سياسات التكويد',v_key; end if;
  v_code := v_prefix||lpad((coalesce(v_max,0)+1)::text,v_digits,'0');
  new := jsonb_populate_record(new,jsonb_build_object(v_column,v_code));
  return new;
end;
$$;

do $$
declare r record;
begin
  for r in
    select * from (values
      ('erp_employees'),('erp_users'),('erp_branches'),('erp_warehouses'),('erp_item_categories'),
      ('erp_accounts'),('erp_cashboxes'),('erp_parties'),
      ('erp_hr_departments'),('erp_hr_jobs'),('erp_hr_work_locations'),('erp_hr_job_grades'),('erp_payroll_runs')
    ) as t(table_name)
  loop
    if to_regclass('public.'||r.table_name) is not null then
      if r.table_name='erp_users' then execute 'drop trigger if exists erp_users_assign_user_code on public.erp_users'; end if;
      execute format('drop trigger if exists %I on public.%I',r.table_name||'_central_code',r.table_name);
      execute format('create trigger %I before insert on public.%I for each row execute function public.erp_assign_central_code()',r.table_name||'_central_code',r.table_name);
    end if;
  end loop;
end $$;

-- Item codes are independent: 3-letter prefix + 2-digit rank at each of
-- the three category levels + 2-digit serial within that exact category path.
create or replace function public.erp_assign_item_hierarchical_code()
returns trigger
language plpgsql security definer set search_path=public as $$
declare
  v_prefix text;
  v_path text[] := array[]::text[];
  v_node record;
  v_parent uuid;
  v_rank integer;
  v_serial integer;
  v_lock text;
begin
  if nullif(new.item_code,'') is not null then return new; end if;
  if new.category_id is null then raise exception 'اختر الفئة الثانوية قبل حفظ الصنف لتوليد كوده'; end if;

  select coalesce(nullif((case when policy_value ~ '^\\s*\\{' then policy_value::jsonb else '{}'::jsonb end)->>'item_prefix',''),'itm')
    into v_prefix
  from public.erp_program_policies
  where company_id=new.company_id and policy_key='code_generation_registry'
  limit 1;
  v_prefix := coalesce(v_prefix,'itm');
  if v_prefix !~ '^[A-Za-z]{3}$' then raise exception 'بادئة كود الأصناف يجب أن تكون ثلاثة أحرف إنجليزية'; end if;

  v_parent := new.category_id;
  for i in 1..3 loop
    select id,parent_id,category_code into v_node
    from public.erp_item_categories
    where id=v_parent and company_id=new.company_id and is_active=true;
    if not found then raise exception 'الفئة المختارة غير موجودة أو غير نشطة'; end if;

    select count(*) into v_rank
    from public.erp_item_categories c
    where c.company_id=new.company_id
      and c.parent_id is not distinct from v_node.parent_id
      and c.is_active=true
      and c.activity_code is not distinct from (select activity_code from public.erp_item_categories where id=new.category_id)
      and (c.category_code,c.id) <= (v_node.category_code,v_node.id);
    if v_rank < 1 or v_rank > 99 then raise exception 'عدد الفئات في كل مستوى يجب ألا يتجاوز 99 لتكوين كود الصنف'; end if;
    v_path := array_prepend(lpad(v_rank::text,2,'0'),v_path);
    v_parent := v_node.parent_id;
    if i<3 and v_parent is null then raise exception 'يجب اختيار فئة ثانوية مرتبطة بفئة فرعية ورئيسية'; end if;
    if i=3 and v_parent is not null then raise exception 'مستويات فئات الأصناف يجب ألا تتجاوز ثلاثة مستويات'; end if;
  end loop;

  v_lock := new.company_id::text||':item:'||v_prefix||array_to_string(v_path,'');
  perform pg_advisory_xact_lock(hashtextextended(v_lock,0));
  select coalesce(max(substring(item_code from (length(v_prefix)+7)::integer for 2)::integer),0)
    into v_serial
  from public.erp_items
  where company_id=new.company_id
    and item_code like v_prefix||array_to_string(v_path,'')||'__'
    and item_code ~ ('^'||v_prefix||array_to_string(v_path,'')||'[0-9]{2}
  if v_serial>=99 then raise exception 'تم الوصول إلى الحد الأقصى 99 صنفًا داخل هذه الفئات'; end if;
  new.item_code := v_prefix||array_to_string(v_path,'')||lpad((coalesce(v_serial,0)+1)::text,2,'0');
  return new;
end;
$$;

drop trigger if exists erp_items_hierarchical_code on public.erp_items;
create trigger erp_items_hierarchical_code before insert on public.erp_items
for each row execute function public.erp_assign_item_hierarchical_code();

create or replace function public.erp_preview_next_central_code(p_company_id uuid,p_entity_key text)
returns text
language plpgsql security definer set search_path=public as $$
declare v_table text; v_column text; v_prefix text; v_digits integer; v_max bigint; v_kind text;
begin
  case p_entity_key
    when 'employee' then v_table:='erp_employees'; v_column:='employee_code'; v_prefix:='Emp';
    when 'user' then v_table:='erp_users'; v_column:='user_code'; v_prefix:='Usr';
    when 'branch' then v_table:='erp_branches'; v_column:='branch_code'; v_prefix:='Brn';
    when 'warehouse' then v_table:='erp_warehouses'; v_column:='warehouse_code'; v_prefix:='Whs';
    when 'account' then v_table:='erp_accounts'; v_column:='account_code'; v_prefix:='Acc';
    when 'cashbox' then v_table:='erp_cashboxes'; v_column:='cashbox_code'; v_prefix:='Csh';
    when 'supplier' then v_table:='erp_parties'; v_column:='party_code'; v_prefix:='Sup'; v_kind:='supplier';
    when 'customer' then v_table:='erp_parties'; v_column:='party_code'; v_prefix:='Cus'; v_kind:='customer';
    when 'department' then v_table:='erp_hr_departments'; v_column:='department_code'; v_prefix:='Dpt';
    when 'job' then v_table:='erp_hr_jobs'; v_column:='job_code'; v_prefix:='Job';
    when 'work_location' then v_table:='erp_hr_work_locations'; v_column:='location_code'; v_prefix:='Loc';
    when 'grade' then v_table:='erp_hr_job_grades'; v_column:='grade_code'; v_prefix:='Grd';
    when 'payroll_run' then v_table:='erp_payroll_runs'; v_column:='run_code'; v_prefix:='Pay';
    when 'category' then v_table:='erp_item_categories'; v_column:='category_code'; v_prefix:='Cat';
    else raise exception 'نوع التكويد غير مدعوم';
  end case;
  select c.prefix,c.digits into v_prefix,v_digits from public.erp_code_policy_config(p_company_id,p_entity_key,v_prefix,5) c;
  if to_regclass('public.'||v_table) is null then raise exception 'جدول نوع التكويد غير متاح'; end if;
  if v_kind is null then
    execute format('select coalesce(max(nullif(substring(%I from %L), '''')::bigint),0) from public.%I where company_id=$1 and %I ~ $2',
      v_column,'^'||v_prefix||'([0-9]+)$',v_table,v_column)
      into v_max using p_company_id,'^'||v_prefix||'[0-9]+$';
  else
    execute format('select coalesce(max(nullif(substring(%I from %L), '''')::bigint),0) from public.%I where company_id=$1 and party_kind=$2 and %I ~ $3',
      v_column,'^'||v_prefix||'([0-9]+)$',v_table,v_column)
      into v_max using p_company_id,v_kind,'^'||v_prefix||'[0-9]+$';
  end if;
  return v_prefix||lpad((coalesce(v_max,0)+1)::text,v_digits,'0');
end;
$$;

revoke all on function public.erp_preview_next_central_code(uuid,text) from public;
grant execute on function public.erp_preview_next_central_code(uuid,text) to authenticated;

-- Respect configured prefixes and digit widths for identity-backed code types.
create or replace function public.erp_set_user_type_display_code()
returns trigger language plpgsql security definer set search_path=public as $
declare p text; d integer;
begin
  select prefix,digits into p,d from public.erp_code_policy_config(new.company_id,'user_type','Typ',5);
  new.type_code_display := p||lpad(new.type_code::text,d,'0');
  return new;
end;
$;
create or replace function public.erp_set_permission_template_display_code()
returns trigger language plpgsql security definer set search_path=public as $
declare p text; d integer;
begin
  select prefix,digits into p,d from public.erp_code_policy_config(new.company_id,'permission_template','Tpl',5);
  new.template_code_display := p||lpad(new.template_code::text,d,'0');
  return new;
end;
$;

commit;
);
  if v_serial>=99 then raise exception 'تم الوصول إلى الحد الأقصى 99 صنفًا داخل هذه الفئات'; end if;
  new.item_code := v_prefix||array_to_string(v_path,'')||lpad((coalesce(v_serial,0)+1)::text,2,'0');
  return new;
end;
$$;

drop trigger if exists erp_items_hierarchical_code on public.erp_items;
create trigger erp_items_hierarchical_code before insert on public.erp_items
for each row execute function public.erp_assign_item_hierarchical_code();

create or replace function public.erp_preview_next_central_code(p_company_id uuid,p_entity_key text)
returns text
language plpgsql security definer set search_path=public as $$
declare v_table text; v_column text; v_prefix text; v_digits integer; v_max bigint; v_kind text;
begin
  case p_entity_key
    when 'employee' then v_table:='erp_employees'; v_column:='employee_code'; v_prefix:='Emp';
    when 'user' then v_table:='erp_users'; v_column:='user_code'; v_prefix:='Usr';
    when 'branch' then v_table:='erp_branches'; v_column:='branch_code'; v_prefix:='Brn';
    when 'warehouse' then v_table:='erp_warehouses'; v_column:='warehouse_code'; v_prefix:='Whs';
    when 'account' then v_table:='erp_accounts'; v_column:='account_code'; v_prefix:='Acc';
    when 'cashbox' then v_table:='erp_cashboxes'; v_column:='cashbox_code'; v_prefix:='Csh';
    when 'supplier' then v_table:='erp_parties'; v_column:='party_code'; v_prefix:='Sup'; v_kind:='supplier';
    when 'customer' then v_table:='erp_parties'; v_column:='party_code'; v_prefix:='Cus'; v_kind:='customer';
    when 'department' then v_table:='erp_hr_departments'; v_column:='department_code'; v_prefix:='Dpt';
    when 'job' then v_table:='erp_hr_jobs'; v_column:='job_code'; v_prefix:='Job';
    when 'work_location' then v_table:='erp_hr_work_locations'; v_column:='location_code'; v_prefix:='Loc';
    when 'grade' then v_table:='erp_hr_job_grades'; v_column:='grade_code'; v_prefix:='Grd';
    when 'payroll_run' then v_table:='erp_payroll_runs'; v_column:='run_code'; v_prefix:='Pay';
    when 'category' then v_table:='erp_item_categories'; v_column:='category_code'; v_prefix:='Cat';
    else raise exception 'نوع التكويد غير مدعوم';
  end case;
  select c.prefix,c.digits into v_prefix,v_digits from public.erp_code_policy_config(p_company_id,p_entity_key,v_prefix,5) c;
  if to_regclass('public.'||v_table) is null then raise exception 'جدول نوع التكويد غير متاح'; end if;
  if v_kind is null then
    execute format('select coalesce(max(nullif(substring(%I from %L), '''')::bigint),0) from public.%I where company_id=$1 and %I ~ $2',
      v_column,'^'||v_prefix||'([0-9]+)$',v_table,v_column)
      into v_max using p_company_id,'^'||v_prefix||'[0-9]+$';
  else
    execute format('select coalesce(max(nullif(substring(%I from %L), '''')::bigint),0) from public.%I where company_id=$1 and party_kind=$2 and %I ~ $3',
      v_column,'^'||v_prefix||'([0-9]+)$',v_table,v_column)
      into v_max using p_company_id,v_kind,'^'||v_prefix||'[0-9]+$';
  end if;
  return v_prefix||lpad((coalesce(v_max,0)+1)::text,v_digits,'0');
end;
$$;

revoke all on function public.erp_preview_next_central_code(uuid,text) from public;
grant execute on function public.erp_preview_next_central_code(uuid,text) to authenticated;

-- Respect configured prefixes and digit widths for identity-backed code types.
create or replace function public.erp_set_user_type_display_code()
returns trigger language plpgsql security definer set search_path=public as $
declare p text; d integer;
begin
  select prefix,digits into p,d from public.erp_code_policy_config(new.company_id,'user_type','Typ',5);
  new.type_code_display := p||lpad(new.type_code::text,d,'0');
  return new;
end;
$;
create or replace function public.erp_set_permission_template_display_code()
returns trigger language plpgsql security definer set search_path=public as $
declare p text; d integer;
begin
  select prefix,digits into p,d from public.erp_code_policy_config(new.company_id,'permission_template','Tpl',5);
  new.template_code_display := p||lpad(new.template_code::text,d,'0');
  return new;
end;
$;

commit;
