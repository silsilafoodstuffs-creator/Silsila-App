-- Central company-scoped code generation for Silsila ERP.
-- Existing records and their codes are preserved. Blank codes on new rows are generated atomically.
begin;

create or replace function public.erp_code_policy_config(
  p_company_id uuid, p_key text, p_default_prefix text, p_default_digits integer
)
returns table(prefix text, digits integer)
language plpgsql stable security definer set search_path = '' as $$
declare
  v jsonb;
  v_cfg jsonb;
begin
  select case when left(policy_value, 1) = '{' then policy_value::jsonb else '{}'::jsonb end
    into v
  from public.erp_program_policies
  where company_id = p_company_id and policy_key = 'code_generation_registry'
  limit 1;
  v_cfg := coalesce(v->'types'->p_key, '{}'::jsonb);
  prefix := coalesce(nullif(v_cfg->>'prefix', ''), p_default_prefix);
  digits := coalesce(nullif(v_cfg->>'digits', '')::integer, p_default_digits);
  if prefix !~ '^[A-Za-z]{3}$' or digits < 1 or digits > 12 then
    raise exception 'إعدادات التكويد غير صحيحة للنوع %', p_key;
  end if;
  return next;
end;
$$;
revoke all on function public.erp_code_policy_config(uuid,text,text,integer) from public, anon, authenticated;

create or replace function public.erp_assign_central_code()
returns trigger
language plpgsql security definer set search_path = '' as $$
declare
  v_company uuid;
  v_key text;
  v_column text;
  v_prefix text;
  v_digits integer;
  v_party_kind text;
  v_doc_type text;
  v_voucher_type text;
  v_max bigint;
  v_code text;
  v_lock text;
begin
  v_company := (to_jsonb(new)->>'company_id')::uuid;
  if v_company is null then raise exception 'company_id مطلوب لتوليد الكود'; end if;

  case tg_table_name
    when 'erp_employees' then v_key := 'employee'; v_column := 'employee_code';
    when 'erp_users' then v_key := 'user'; v_column := 'user_code';
    when 'erp_branches' then v_key := 'branch'; v_column := 'branch_code';
    when 'erp_warehouses' then v_key := 'warehouse'; v_column := 'warehouse_code';
    when 'erp_item_categories' then v_key := 'category'; v_column := 'category_code';
    when 'erp_cost_centers' then v_key := 'cost_center'; v_column := 'center_code';
    when 'erp_price_lists' then v_key := 'price_list'; v_column := 'price_list_code';
    when 'erp_accounts' then v_key := 'account'; v_column := 'account_code';
    when 'erp_cashboxes' then v_key := 'cashbox'; v_column := 'cashbox_code';
    when 'erp_parties' then
      v_party_kind := coalesce(to_jsonb(new)->>'party_kind', 'supplier');
      v_key := case when v_party_kind = 'customer' then 'customer' else 'supplier' end;
      v_column := 'party_code';
    when 'erp_sales_representatives' then v_key := 'delegate'; v_column := 'rep_code';
    when 'erp_sales_documents' then
      v_doc_type := to_jsonb(new)->>'document_type';
      v_key := case v_doc_type
        when 'quotation' then 'quotation'
        when 'order' then 'sales_order'
        when 'delivery' then 'sales_delivery'
        when 'return' then 'sales_return'
        else 'sales_invoice' end;
      v_column := 'document_number';
    when 'erp_purchase_documents' then
      v_doc_type := to_jsonb(new)->>'document_type';
      v_key := case v_doc_type
        when 'order' then 'purchase_order'
        when 'receipt' then 'purchase_receipt'
        when 'return' then 'purchase_return'
        else 'purchase_invoice' end;
      v_column := 'document_number';
    when 'erp_cash_vouchers' then
      v_voucher_type := to_jsonb(new)->>'voucher_type';
      v_key := case v_voucher_type
        when 'payment' then 'cash_payment'
        when 'transfer' then 'cash_transfer'
        else 'cash_receipt' end;
      v_column := 'voucher_number';
    when 'erp_hr_departments' then v_key := 'department'; v_column := 'department_code';
    when 'erp_hr_jobs' then v_key := 'job'; v_column := 'job_code';
    when 'erp_hr_work_locations' then v_key := 'work_location'; v_column := 'location_code';
    when 'erp_hr_job_grades' then v_key := 'grade'; v_column := 'grade_code';
    when 'erp_payroll_runs' then v_key := 'payroll_run'; v_column := 'run_code';
    else raise exception 'نوع سجل غير مدعوم في التكويد المركزي: %', tg_table_name;
  end case;

  if nullif(to_jsonb(new)->>v_column, '') is not null then return new; end if;

  select c.prefix, c.digits into v_prefix, v_digits
  from public.erp_code_policy_config(
    v_company, v_key,
    case v_key
      when 'employee' then 'Emp'
      when 'user' then 'Usr'
      when 'branch' then 'Brn'
      when 'warehouse' then 'Whs'
      when 'category' then 'Cat'
      when 'cost_center' then 'Cst'
      when 'price_list' then 'Prc'
      when 'account' then 'Acc'
      when 'cashbox' then 'Csh'
      when 'supplier' then 'Sup'
      when 'customer' then 'Cus'
      when 'department' then 'Dpt'
      when 'job' then 'Job'
      when 'work_location' then 'Loc'
      when 'grade' then 'Grd'
      when 'payroll_run' then 'Pay'
      when 'delegate' then 'Del'
      when 'sales_invoice' then 'Siv'
      when 'sales_order' then 'Sor'
      when 'quotation' then 'Qot'
      when 'sales_delivery' then 'Dlv'
      when 'sales_return' then 'Srt'
      when 'purchase_invoice' then 'Piv'
      when 'purchase_order' then 'Por'
      when 'purchase_receipt' then 'Prc'
      when 'purchase_return' then 'Prt'
      when 'cash_receipt' then 'Rcp'
      when 'cash_payment' then 'Pay'
      when 'cash_transfer' then 'Trf'
      else 'Gen'
    end, 5
  ) c;

  v_lock := v_company::text || ':' || tg_table_name || ':' || v_prefix;
  perform pg_advisory_xact_lock(hashtextextended(v_lock, 0));

  -- Scan the full entity table by prefix, not by subtype, so even duplicate
  -- user-configured prefixes cannot produce duplicate identifiers.
  execute format(
    'select coalesce(max(substring(%I from %L)::bigint), 0) from public.%I where company_id = $1 and %I ~ $2',
    v_column, '^' || v_prefix || '([0-9]+)$', tg_table_name, v_column
  ) into v_max using v_company, '^' || v_prefix || '[0-9]+$';

  if coalesce(v_max, 0) + 1 >= power(10::numeric, v_digits) then
    raise exception 'انتهت خانات الكود للنوع %؛ زد عدد الخانات من سياسات التكويد', v_key;
  end if;
  v_code := v_prefix || lpad((coalesce(v_max, 0) + 1)::text, v_digits, '0');
  new := jsonb_populate_record(new, jsonb_build_object(v_column, v_code));
  return new;
end;
$$;
revoke all on function public.erp_assign_central_code() from public, anon, authenticated;

do $$
declare r record;
begin
  for r in
    select * from (values
      ('erp_employees'), ('erp_users'), ('erp_branches'), ('erp_warehouses'),
      ('erp_item_categories'), ('erp_cost_centers'), ('erp_price_lists'),
      ('erp_accounts'), ('erp_cashboxes'), ('erp_parties'),
      ('erp_hr_departments'), ('erp_hr_jobs'), ('erp_hr_work_locations'),
      ('erp_hr_job_grades'), ('erp_payroll_runs'), ('erp_sales_representatives'),
      ('erp_sales_documents'), ('erp_purchase_documents'), ('erp_cash_vouchers')
    ) as t(table_name)
  loop
    if to_regclass('public.' || r.table_name) is not null then
      if r.table_name = 'erp_users' then
        execute 'drop trigger if exists erp_users_assign_user_code on public.erp_users';
      end if;
      execute format('drop trigger if exists %I on public.%I', r.table_name || '_central_code', r.table_name);
      execute format(
        'create trigger %I before insert on public.%I for each row execute function public.erp_assign_central_code()',
        r.table_name || '_central_code', r.table_name
      );
    end if;
  end loop;
end;
$$;

create or replace function public.erp_assign_item_hierarchical_code()
returns trigger
language plpgsql security definer set search_path = '' as $$
declare
  v_prefix text;
  v_path text[] := array[]::text[];
  v_node record;
  v_parent uuid;
  v_rank integer;
  v_serial integer;
  v_lock text;
begin
  if nullif(new.item_code, '') is not null then return new; end if;
  if new.category_id is null then
    raise exception 'اختر الفئة الثانوية قبل حفظ الصنف لتوليد كوده';
  end if;

  select coalesce(
    nullif(
      (case when left(policy_value, 1) = '{' then policy_value::jsonb else '{}'::jsonb end)->>'item_prefix',
      ''
    ),
    'itm'
  ) into v_prefix
  from public.erp_program_policies
  where company_id = new.company_id and policy_key = 'code_generation_registry'
  limit 1;
  v_prefix := coalesce(v_prefix, 'itm');
  if v_prefix !~ '^[A-Za-z]{3}$' then
    raise exception 'بادئة كود الأصناف يجب أن تكون ثلاثة أحرف إنجليزية';
  end if;

  v_parent := new.category_id;
  for i in 1..3 loop
    select id, parent_id, category_code into v_node
    from public.erp_item_categories
    where id = v_parent and company_id = new.company_id and is_active = true;
    if not found then raise exception 'الفئة المختارة غير موجودة أو غير نشطة'; end if;

    select count(*) into v_rank
    from public.erp_item_categories c
    where c.company_id = new.company_id
      and c.parent_id is not distinct from v_node.parent_id
      and c.is_active = true
      and c.activity_code is not distinct from (
        select activity_code from public.erp_item_categories where id = new.category_id
      )
      and (c.category_code, c.id) <= (v_node.category_code, v_node.id);

    if v_rank < 1 or v_rank > 99 then
      raise exception 'عدد الفئات في كل مستوى يجب ألا يتجاوز 99 لتكوين كود الصنف';
    end if;
    v_path := array_prepend(lpad(v_rank::text, 2, '0'), v_path);
    v_parent := v_node.parent_id;
    if i < 3 and v_parent is null then
      raise exception 'يجب اختيار فئة ثانوية مرتبطة بفئة فرعية ورئيسية';
    end if;
    if i = 3 and v_parent is not null then
      raise exception 'مستويات فئات الأصناف يجب ألا تتجاوز ثلاثة مستويات';
    end if;
  end loop;

  v_lock := new.company_id::text || ':item:' || v_prefix || array_to_string(v_path, '');
  perform pg_advisory_xact_lock(hashtextextended(v_lock, 0));

  select coalesce(max(right(item_code, 2)::integer), 0) into v_serial
  from public.erp_items
  where company_id = new.company_id
    and item_code ~ ('^' || v_prefix || array_to_string(v_path, '') || '[0-9]{2}$');

  if v_serial >= 99 then
    raise exception 'تم الوصول إلى الحد الأقصى 99 صنفًا داخل هذه الفئات';
  end if;
  new.item_code := v_prefix || array_to_string(v_path, '') ||
    lpad((coalesce(v_serial, 0) + 1)::text, 2, '0');
  return new;
end;
$$;
revoke all on function public.erp_assign_item_hierarchical_code() from public, anon, authenticated;

drop trigger if exists erp_items_hierarchical_code on public.erp_items;
create trigger erp_items_hierarchical_code before insert on public.erp_items
for each row execute function public.erp_assign_item_hierarchical_code();

create or replace function public.erp_preview_next_central_code(
  p_company_id uuid, p_entity_key text
)
returns text
language plpgsql security invoker set search_path = '' as $
declare
  v_table text;
  v_column text;
  v_prefix text;
  v_digits integer;
  v_policy_prefix text;
  v_policy_digits integer;
  v_max bigint;
begin
  if auth.uid() is null or not public.erp_user_can_access_company(p_company_id) then
    raise exception 'غير مصرح بمعاينة أكواد هذه الشركة';
  end if;

  case p_entity_key
    when 'employee' then v_table := 'erp_employees'; v_column := 'employee_code'; v_prefix := 'Emp';
    when 'user' then v_table := 'erp_users'; v_column := 'user_code'; v_prefix := 'Usr';
    when 'branch' then v_table := 'erp_branches'; v_column := 'branch_code'; v_prefix := 'Brn';
    when 'warehouse' then v_table := 'erp_warehouses'; v_column := 'warehouse_code'; v_prefix := 'Whs';
    when 'category' then v_table := 'erp_item_categories'; v_column := 'category_code'; v_prefix := 'Cat';
    when 'cost_center' then v_table := 'erp_cost_centers'; v_column := 'center_code'; v_prefix := 'Cst';
    when 'price_list' then v_table := 'erp_price_lists'; v_column := 'price_list_code'; v_prefix := 'Prc';
    when 'account' then v_table := 'erp_accounts'; v_column := 'account_code'; v_prefix := 'Acc';
    when 'cashbox' then v_table := 'erp_cashboxes'; v_column := 'cashbox_code'; v_prefix := 'Csh';
    when 'supplier' then v_table := 'erp_parties'; v_column := 'party_code'; v_prefix := 'Sup';
    when 'customer' then v_table := 'erp_parties'; v_column := 'party_code'; v_prefix := 'Cus';
    when 'department' then v_table := 'erp_hr_departments'; v_column := 'department_code'; v_prefix := 'Dpt';
    when 'job' then v_table := 'erp_hr_jobs'; v_column := 'job_code'; v_prefix := 'Job';
    when 'work_location' then v_table := 'erp_hr_work_locations'; v_column := 'location_code'; v_prefix := 'Loc';
    when 'grade' then v_table := 'erp_hr_job_grades'; v_column := 'grade_code'; v_prefix := 'Grd';
    when 'payroll_run' then v_table := 'erp_payroll_runs'; v_column := 'run_code'; v_prefix := 'Pay';
    when 'delegate' then v_table := 'erp_sales_representatives'; v_column := 'rep_code'; v_prefix := 'Del';
    when 'sales_invoice' then v_table := 'erp_sales_documents'; v_column := 'document_number'; v_prefix := 'Siv';
    when 'sales_order' then v_table := 'erp_sales_documents'; v_column := 'document_number'; v_prefix := 'Sor';
    when 'quotation' then v_table := 'erp_sales_documents'; v_column := 'document_number'; v_prefix := 'Qot';
    when 'sales_delivery' then v_table := 'erp_sales_documents'; v_column := 'document_number'; v_prefix := 'Dlv';
    when 'sales_return' then v_table := 'erp_sales_documents'; v_column := 'document_number'; v_prefix := 'Srt';
    when 'purchase_invoice' then v_table := 'erp_purchase_documents'; v_column := 'document_number'; v_prefix := 'Piv';
    when 'purchase_order' then v_table := 'erp_purchase_documents'; v_column := 'document_number'; v_prefix := 'Por';
    when 'purchase_receipt' then v_table := 'erp_purchase_documents'; v_column := 'document_number'; v_prefix := 'Prc';
    when 'purchase_return' then v_table := 'erp_purchase_documents'; v_column := 'document_number'; v_prefix := 'Prt';
    when 'cash_receipt' then v_table := 'erp_cash_vouchers'; v_column := 'voucher_number'; v_prefix := 'Rcp';
    when 'cash_payment' then v_table := 'erp_cash_vouchers'; v_column := 'voucher_number'; v_prefix := 'Pay';
    when 'cash_transfer' then v_table := 'erp_cash_vouchers'; v_column := 'voucher_number'; v_prefix := 'Trf';
    else raise exception 'نوع التكويد غير مدعوم';
  end case;

  select
    nullif((case when left(policy_value, 1) = '{' then policy_value::jsonb else '{}'::jsonb end)->'types'->p_entity_key->>'prefix', ''),
    nullif((case when left(policy_value, 1) = '{' then policy_value::jsonb else '{}'::jsonb end)->'types'->p_entity_key->>'digits', '')::integer
  into v_policy_prefix, v_policy_digits
  from public.erp_program_policies
  where company_id = p_company_id and policy_key = 'code_generation_registry'
  limit 1;
  v_prefix := coalesce(v_policy_prefix, v_prefix);
  v_digits := coalesce(v_policy_digits, 5);
  if v_prefix !~ '^[A-Za-z]{3}
    raise exception 'جدول نوع التكويد غير متاح';
  end if;
  execute format(
    'select coalesce(max(substring(%I from %L)::bigint), 0) from public.%I where company_id = $1 and %I ~ $2',
    v_column, '^' || v_prefix || '([0-9]+)$', v_table, v_column
  ) into v_max using p_company_id, '^' || v_prefix || '[0-9]+$';
  if coalesce(v_max, 0) + 1 >= power(10::numeric, v_digits) then
    raise exception 'انتهت خانات الكود؛ زد عدد الخانات من سياسات التكويد';
  end if;
  return v_prefix || lpad((coalesce(v_max, 0) + 1)::text, v_digits, '0');
end;
$$;
revoke all on function public.erp_preview_next_central_code(uuid, text) from public, anon;
grant execute on function public.erp_preview_next_central_code(uuid, text) to authenticated;

create or replace function public.erp_set_user_type_display_code()
returns trigger language plpgsql security definer set search_path = '' as $$
declare p text; d integer;
begin
  select prefix, digits into p, d
  from public.erp_code_policy_config(new.company_id, 'user_type', 'Typ', 5);
  new.type_code_display := p || lpad(new.type_code::text, d, '0');
  return new;
end;
$$;
create or replace function public.erp_set_permission_template_display_code()
returns trigger language plpgsql security definer set search_path = '' as $$
declare p text; d integer;
begin
  select prefix, digits into p, d
  from public.erp_code_policy_config(new.company_id, 'permission_template', 'Tpl', 5);
  new.template_code_display := p || lpad(new.template_code::text, d, '0');
  return new;
end;
$$;

drop trigger if exists erp_user_types_central_display_code on public.erp_user_types;
create trigger erp_user_types_central_display_code
before insert or update of company_id, type_code on public.erp_user_types
for each row execute function public.erp_set_user_type_display_code();
drop trigger if exists erp_permission_templates_central_display_code on public.erp_permission_templates;
create trigger erp_permission_templates_central_display_code
before insert or update of company_id, template_code on public.erp_permission_templates
for each row execute function public.erp_set_permission_template_display_code();
revoke all on function public.erp_set_user_type_display_code() from public, anon, authenticated;
revoke all on function public.erp_set_permission_template_display_code() from public, anon, authenticated;

-- Preserve price-list default switching in one transaction while the trigger assigns its code.
create or replace function public.erp_create_price_list(
  p_company_id uuid, p_code text, p_name text, p_kind text,
  p_is_default boolean default false, p_currency_code text default 'EGP', p_notes text default null
)
returns uuid language plpgsql security definer set search_path = '' set row_security = off as $$
declare v_id uuid; v_currency text := upper(coalesce(nullif(trim(p_currency_code), ''), 'EGP'));
begin
  if not public.erp_user_has_company_role(p_company_id, array['owner','admin','manager','accountant']::text[]) then
    raise exception 'ليست لديك صلاحية إنشاء قوائم الأسعار';
  end if;
  if nullif(trim(p_name), '') is null then raise exception 'اسم قائمة الأسعار مطلوب'; end if;
  if p_kind is null or p_kind not in ('sale','purchase') then raise exception 'نوع قائمة الأسعار غير صحيح'; end if;
  if length(v_currency) <> 3 then raise exception 'رمز العملة يجب أن يتكون من ثلاثة أحرف'; end if;
  perform pg_advisory_xact_lock(hashtextextended(p_company_id::text || ':price-list:' || p_kind, 0));
  if coalesce(p_is_default, false) then
    update public.erp_price_lists set is_default=false, updated_at=now()
    where company_id=p_company_id and price_kind=p_kind and is_active and is_default;
  end if;
  insert into public.erp_price_lists(company_id,price_list_code,price_list_name,price_kind,currency_code,is_default,is_active,notes)
  values(p_company_id,'',trim(p_name),p_kind,v_currency::char(3),coalesce(p_is_default,false),true,nullif(trim(p_notes),''))
  returning id into v_id;
  return v_id;
end;
$$;
revoke all on function public.erp_create_price_list(uuid,text,text,text,boolean,text,text) from public, anon;
grant execute on function public.erp_create_price_list(uuid,text,text,text,boolean,text,text) to authenticated;

commit;
 or v_digits < 1 or v_digits > 12 then
    raise exception 'إعدادات التكويد غير صحيحة';
  end if;
  if to_regclass('public.' || v_table) is null then
    raise exception 'جدول نوع التكويد غير متاح';
  end if;
  execute format(
    'select coalesce(max(substring(%I from %L)::bigint), 0) from public.%I where company_id = $1 and %I ~ $2',
    v_column, '^' || v_prefix || '([0-9]+)$', v_table, v_column
  ) into v_max using p_company_id, '^' || v_prefix || '[0-9]+$';
  if coalesce(v_max, 0) + 1 >= power(10::numeric, v_digits) then
    raise exception 'انتهت خانات الكود؛ زد عدد الخانات من سياسات التكويد';
  end if;
  return v_prefix || lpad((coalesce(v_max, 0) + 1)::text, v_digits, '0');
end;
$$;
revoke all on function public.erp_preview_next_central_code(uuid, text) from public, anon;
grant execute on function public.erp_preview_next_central_code(uuid, text) to authenticated;

create or replace function public.erp_set_user_type_display_code()
returns trigger language plpgsql security definer set search_path = '' as $$
declare p text; d integer;
begin
  select prefix, digits into p, d
  from public.erp_code_policy_config(new.company_id, 'user_type', 'Typ', 5);
  new.type_code_display := p || lpad(new.type_code::text, d, '0');
  return new;
end;
$$;
create or replace function public.erp_set_permission_template_display_code()
returns trigger language plpgsql security definer set search_path = '' as $$
declare p text; d integer;
begin
  select prefix, digits into p, d
  from public.erp_code_policy_config(new.company_id, 'permission_template', 'Tpl', 5);
  new.template_code_display := p || lpad(new.template_code::text, d, '0');
  return new;
end;
$$;

drop trigger if exists erp_user_types_central_display_code on public.erp_user_types;
create trigger erp_user_types_central_display_code
before insert or update of company_id, type_code on public.erp_user_types
for each row execute function public.erp_set_user_type_display_code();
drop trigger if exists erp_permission_templates_central_display_code on public.erp_permission_templates;
create trigger erp_permission_templates_central_display_code
before insert or update of company_id, template_code on public.erp_permission_templates
for each row execute function public.erp_set_permission_template_display_code();
revoke all on function public.erp_set_user_type_display_code() from public, anon, authenticated;
revoke all on function public.erp_set_permission_template_display_code() from public, anon, authenticated;

-- Preserve price-list default switching in one transaction while the trigger assigns its code.
create or replace function public.erp_create_price_list(
  p_company_id uuid, p_code text, p_name text, p_kind text,
  p_is_default boolean default false, p_currency_code text default 'EGP', p_notes text default null
)
returns uuid language plpgsql security definer set search_path = '' set row_security = off as $$
declare v_id uuid; v_currency text := upper(coalesce(nullif(trim(p_currency_code), ''), 'EGP'));
begin
  if not public.erp_user_has_company_role(p_company_id, array['owner','admin','manager','accountant']::text[]) then
    raise exception 'ليست لديك صلاحية إنشاء قوائم الأسعار';
  end if;
  if nullif(trim(p_name), '') is null then raise exception 'اسم قائمة الأسعار مطلوب'; end if;
  if p_kind is null or p_kind not in ('sale','purchase') then raise exception 'نوع قائمة الأسعار غير صحيح'; end if;
  if length(v_currency) <> 3 then raise exception 'رمز العملة يجب أن يتكون من ثلاثة أحرف'; end if;
  perform pg_advisory_xact_lock(hashtextextended(p_company_id::text || ':price-list:' || p_kind, 0));
  if coalesce(p_is_default, false) then
    update public.erp_price_lists set is_default=false, updated_at=now()
    where company_id=p_company_id and price_kind=p_kind and is_active and is_default;
  end if;
  insert into public.erp_price_lists(company_id,price_list_code,price_list_name,price_kind,currency_code,is_default,is_active,notes)
  values(p_company_id,'',trim(p_name),p_kind,v_currency::char(3),coalesce(p_is_default,false),true,nullif(trim(p_notes),''))
  returning id into v_id;
  return v_id;
end;
$$;
revoke all on function public.erp_create_price_list(uuid,text,text,text,boolean,text,text) from public, anon;
grant execute on function public.erp_create_price_list(uuid,text,text,text,boolean,text,text) to authenticated;

commit;
