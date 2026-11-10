-- Applied migration 20261110233419: preserve alphanumeric parent-code suffixes in composite codes
BEGIN;
CREATE OR REPLACE FUNCTION public.erp_assign_central_code()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
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
  v_parent_warehouse_id uuid;
  v_parent_warehouse_code text;
  v_parent_parent_id uuid;
  v_parent_branch_id uuid;
  v_branch_id uuid;
  v_branch_code text;
  v_branch_segment text;
  v_parent_segment text;
  v_parent_department_id uuid;
  v_parent_department_code text;
  v_parent_department_level text;
begin
  v_company := (to_jsonb(new)->>'company_id')::uuid;
  if v_company is null then raise exception 'company_id مطلوب لتوليد الكود'; end if;

  case tg_table_name
    when 'erp_employees' then v_key := 'employee'; v_column := 'employee_code';
    when 'erp_users' then v_key := 'user'; v_column := 'user_code';
    when 'erp_branches' then v_key := 'branch'; v_column := 'branch_code';
    when 'erp_warehouses' then
      v_key := case when nullif(to_jsonb(new)->>'parent_warehouse_id','') is null then 'warehouse' else 'storage_location' end;
      v_column := 'warehouse_code';
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
    when 'erp_checkbooks' then v_key := 'checkbook'; v_column := 'book_number';
    when 'erp_cash_movements' then v_key := 'cash_movement'; v_column := 'movement_number';
    when 'erp_cash_orders' then v_key := 'cash_order'; v_column := 'order_number';
    when 'erp_cash_vouchers' then
      v_voucher_type := to_jsonb(new)->>'voucher_type';
      v_key := case v_voucher_type
        when 'payment' then 'cash_payment'
        when 'transfer' then 'cash_transfer'
        else 'cash_receipt' end;
      v_column := 'voucher_number';
    when 'erp_hr_departments' then
      v_key := case when to_jsonb(new)->>'department_level'='section' then 'section' else 'department' end;
      v_column := 'department_code';
    when 'erp_hr_jobs' then v_key := 'job'; v_column := 'job_code';
    when 'erp_hr_work_locations' then v_key := 'work_location'; v_column := 'location_code';
    when 'erp_hr_job_grades' then v_key := 'grade'; v_column := 'grade_code';
    when 'erp_payroll_runs' then v_key := 'payroll_run'; v_column := 'run_code';
    when 'erp_hr_salary_elements' then v_key := 'salary_element'; v_column := 'element_code';
    when 'erp_item_unit_catalog' then v_key := 'unit'; v_column := 'unit_code';
    when 'erp_payment_methods' then v_key := 'payment_method'; v_column := 'payment_method_code';
    when 'erp_hr_shifts' then v_key := 'shift'; v_column := 'shift_code';
    when 'erp_commission_plans' then v_key := 'commission_plan'; v_column := 'plan_code';
    when 'erp_sales_fulfillment_documents' then v_key := 'sales_fulfillment'; v_column := 'manual_number';
    when 'erp_user_classifications' then v_key := 'user_classification'; v_column := 'classification_code_display';
    when 'erp_journal_entries' then v_key := 'journal_entry'; v_column := 'entry_number_display';
    else raise exception 'نوع سجل غير مدعوم في التكويد المركزي: %', tg_table_name;
  end case;

  if tg_table_name = 'erp_item_categories' then return new; end if;
  if nullif(to_jsonb(new)->>v_column, '') is not null then return new; end if;

  select c.prefix, c.digits into v_prefix, v_digits
  from public.erp_code_policy_config(
    v_company, v_key,
    case v_key
      when 'employee' then 'Emp'
      when 'user' then 'Usr'
      when 'branch' then 'Brn'
      when 'warehouse' then 'Whs'
      when 'storage_location' then 'Loc'
      when 'section' then 'Sec'
      when 'category' then 'Cat'
      when 'cost_center' then 'Cst'
      when 'price_list' then 'Pli'
      when 'account' then 'Acc'
      when 'cashbox' then 'Csh'
      when 'supplier' then 'Ven'
      when 'customer' then 'Cus'
      when 'department' then 'Dep'
      when 'job' then 'Job'
      when 'work_location' then 'Plc'
      when 'grade' then 'Grd'
      when 'payroll_run' then 'Prl'
      when 'salary_element' then 'Elm'
      when 'unit' then 'Unt'
      when 'payment_method' then 'Pmt'
      when 'shift' then 'Shf'
      when 'commission_plan' then 'Com'
      when 'sales_fulfillment' then 'Ful'
      when 'user_classification' then 'Cls'
      when 'journal_entry' then 'Jrn'
      when 'delegate' then 'Rep'
      when 'sales_invoice' then 'Siv'
      when 'sales_order' then 'Sor'
      when 'quotation' then 'Qot'
      when 'sales_delivery' then 'Dlv'
      when 'sales_return' then 'Srt'
      when 'purchase_invoice' then 'Piv'
      when 'purchase_order' then 'Por'
      when 'purchase_receipt' then 'Prr'
      when 'purchase_return' then 'Prt'
      when 'cash_receipt' then 'Rcp'
      when 'cash_payment' then 'Cpy'
      when 'cash_transfer' then 'Trf'
      when 'checkbook' then 'Ckb'
      when 'cash_movement' then 'Cmv'
      when 'cash_order' then 'Cso'
      else 'Gen'
    end,
    case v_key
      when 'customer' then 4
      when 'branch' then 3
      when 'storage_location' then 3
      when 'department' then 3
      when 'section' then 3
      when 'work_location' then 3
      when 'grade' then 3
      when 'salary_element' then 3
      else 5
    end
  ) c;

  if tg_table_name='erp_warehouses' and v_key='storage_location' then
    v_parent_warehouse_id:=nullif(to_jsonb(new)->>'parent_warehouse_id','')::uuid;
    select w.warehouse_code,w.parent_warehouse_id,w.branch_id into v_parent_warehouse_code,v_parent_parent_id,v_parent_branch_id
    from public.erp_warehouses w where w.id=v_parent_warehouse_id and w.company_id=v_company and w.is_active=true;
    if not found then raise exception 'اختر مخزنًا رئيسيًا نشطًا لموقع التخزين'; end if;
    if v_parent_parent_id is not null then raise exception 'موقع التخزين يجب أن يرتبط بمخزن رئيسي وليس بموقع تخزين آخر'; end if;
    v_branch_id:=coalesce(nullif(to_jsonb(new)->>'branch_id','')::uuid,v_parent_branch_id);
    if v_branch_id is null then raise exception 'حدد الفرع لموقع التخزين أو اربطه بمخزن رئيسي مرتبط بفرع'; end if;
    if v_parent_branch_id is not null then
      if v_branch_id is distinct from v_parent_branch_id then raise exception 'يجب أن يتبع موقع التخزين نفس فرع المخزن الرئيسي'; end if;
    end if;
    select b.branch_code into v_branch_code from public.erp_branches b where b.id=v_branch_id and b.company_id=v_company and b.is_active=true;
    if v_branch_code is null then raise exception 'الفرع المحدد غير نشط أو غير تابع للشركة'; end if;
    v_branch_segment:=regexp_replace(regexp_replace(v_branch_code,'^[A-Za-z]{2,3}[-_]?',''),'[^A-Za-z0-9]','','g');
    v_parent_segment:=regexp_replace(regexp_replace(v_parent_warehouse_code,'^[A-Za-z]{2,3}[-_]?',''),'[^A-Za-z0-9]','','g');
    if v_branch_segment='' then raise exception 'كود الفرع لا يحتوي على جزء صالح بعد البادئة لإنشاء كود موقع التخزين'; end if;
    if v_parent_segment='' then raise exception 'كود المخزن الرئيسي لا يحتوي على جزء صالح بعد البادئة لإنشاء كود موقع التخزين'; end if;
    if length(v_prefix) <> 3 then raise exception 'بادئة سياسة مواقع التخزين غير صحيحة'; end if;
    if translate(v_prefix,'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz','') <> '' then raise exception 'بادئة سياسة مواقع التخزين يجب أن تكون حروفًا إنجليزية'; end if;
    if v_digits < 1 then raise exception 'عدد خانات سياسة مواقع التخزين غير صحيح'; end if;
    if v_digits > 6 then raise exception 'عدد خانات سياسة مواقع التخزين غير صحيح'; end if;
    new:=jsonb_populate_record(new,jsonb_build_object('branch_id',v_branch_id));
    v_lock:=v_company::text||':storage_location:'||v_prefix;
    perform pg_advisory_xact_lock(hashtextextended(v_lock,0));
    select coalesce(max(right(w.warehouse_code,v_digits)::bigint),0) into v_max
    from public.erp_warehouses w where w.company_id=v_company and w.parent_warehouse_id is not null and w.id is distinct from new.id
      and w.warehouse_code ~ ('^'||v_prefix||'[A-Za-z0-9]+[0-9]{'||v_digits||'}$');
    if coalesce(v_max,0)+1>=power(10::numeric,v_digits) then raise exception 'انتهت خانات تسلسل مواقع التخزين؛ زد عدد الخانات من سياسات التكويد'; end if;
    v_code:=v_prefix||v_branch_segment||v_parent_segment||lpad((coalesce(v_max,0)+1)::text,v_digits,'0');
    new:=jsonb_populate_record(new,jsonb_build_object('warehouse_code',v_code));
    return new;
  end if;
  if tg_table_name='erp_hr_departments' and v_key='section' then
    v_parent_department_id:=nullif(to_jsonb(new)->>'parent_id','')::uuid;
    select p.department_code,p.department_level into v_parent_department_code,v_parent_department_level
    from public.erp_hr_departments p where p.id=v_parent_department_id and p.company_id=v_company and p.is_active=true;
    if not found then raise exception 'اختر إدارة أو قسمًا رئيسيًا نشطًا لإنشاء القسم'; end if;
    if v_parent_department_level not in ('directorate','department') then raise exception 'لا يمكن إنشاء قسم فرعي تحت قسم فرعي آخر'; end if;
    v_parent_segment:=regexp_replace(regexp_replace(v_parent_department_code,'^[A-Za-z]{2,3}[-_]?',''),'[^A-Za-z0-9]','','g');
    if v_parent_segment='' then raise exception 'كود الإدارة الأب لا يحتوي على جزء صالح بعد البادئة لتوليد كود القسم'; end if;
    if length(v_prefix) <> 3 then raise exception 'بادئة سياسة الأقسام غير صحيحة'; end if;
    if translate(v_prefix,'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz','') <> '' then raise exception 'بادئة سياسة الأقسام يجب أن تكون حروفًا إنجليزية'; end if;
    if v_digits < 1 then raise exception 'عدد خانات سياسة الأقسام غير صحيح'; end if;
    if v_digits > 6 then raise exception 'عدد خانات سياسة الأقسام غير صحيح'; end if;
    v_lock:=v_company::text||':section:'||v_prefix;
    perform pg_advisory_xact_lock(hashtextextended(v_lock,0));
    select coalesce(max(right(d.department_code,v_digits)::bigint),0) into v_max
    from public.erp_hr_departments d where d.company_id=v_company and d.department_level='section' and d.id is distinct from new.id
      and d.department_code ~ ('^'||v_prefix||'[A-Za-z0-9]+[0-9]{'||v_digits||'}$');
    if coalesce(v_max,0)+1>=power(10::numeric,v_digits) then raise exception 'انتهت خانات تسلسل الأقسام؛ زد عدد الخانات من سياسات التكويد'; end if;
    v_code:=v_prefix||v_parent_segment||lpad((coalesce(v_max,0)+1)::text,v_digits,'0');
    new:=jsonb_populate_record(new,jsonb_build_object('department_code',v_code));
    return new;
  end if;

  v_lock := v_company::text || ':' || tg_table_name || ':' || v_prefix;
  perform pg_advisory_xact_lock(hashtextextended(v_lock, 0));

  -- Prefix-wide scan prevents duplicate codes even if two types share a configured prefix.
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
$function$
;
UPDATE public.erp_program_policies
SET policy_value=jsonb_set(policy_value::jsonb,'{inheritance}',to_jsonb('يرث كود الفرع والمخزن بدون البادئتين، مع تسلسل عام على مستوى الشركة لمنع التكرار'::text),true)::text,updated_at=now()
WHERE policy_key='code_policy.storage_location' AND left(policy_value,1)='{';
UPDATE public.erp_program_policies
SET policy_value=jsonb_set(policy_value::jsonb,'{inheritance}',to_jsonb('يرث كود الإدارة بدون البادئة، مع تسلسل عام على مستوى الشركة لمنع التكرار'::text),true)::text,updated_at=now()
WHERE policy_key='code_policy.section' AND left(policy_value,1)='{';

COMMIT;
