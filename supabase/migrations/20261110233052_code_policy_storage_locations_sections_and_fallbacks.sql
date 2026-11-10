-- Applied migration 20261110233052: align policy fallback values and activate composite section/storage-location codes
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
  v_branch_digits text;
  v_parent_digits text;
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
    v_branch_digits:=regexp_replace(v_branch_code,'[^0-9]','','g');
    v_parent_digits:=regexp_replace(v_parent_warehouse_code,'[^0-9]','','g');
    if v_branch_digits='' then raise exception 'كود الفرع لا يحتوي على أرقام لإنشاء كود موقع التخزين'; end if;
    if v_parent_digits='' then raise exception 'كود المخزن الرئيسي لا يحتوي على أرقام لإنشاء كود موقع التخزين'; end if;
    if length(v_prefix) <> 3 then raise exception 'بادئة سياسة مواقع التخزين غير صحيحة'; end if;
    if translate(v_prefix,'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz','') <> '' then raise exception 'بادئة سياسة مواقع التخزين يجب أن تكون حروفًا إنجليزية'; end if;
    if v_digits < 1 then raise exception 'عدد خانات سياسة مواقع التخزين غير صحيح'; end if;
    if v_digits > 6 then raise exception 'عدد خانات سياسة مواقع التخزين غير صحيح'; end if;
    new:=jsonb_populate_record(new,jsonb_build_object('branch_id',v_branch_id));
    v_lock:=v_company::text||':storage_location:'||v_prefix;
    perform pg_advisory_xact_lock(hashtextextended(v_lock,0));
    select coalesce(max(right(w.warehouse_code,v_digits)::bigint),0) into v_max
    from public.erp_warehouses w where w.company_id=v_company and w.parent_warehouse_id is not null and w.id is distinct from new.id
      and w.warehouse_code ~ ('^'||v_prefix||'[0-9]+[0-9]{'||v_digits||'}$');
    if coalesce(v_max,0)+1>=power(10::numeric,v_digits) then raise exception 'انتهت خانات تسلسل مواقع التخزين؛ زد عدد الخانات من سياسات التكويد'; end if;
    v_code:=v_prefix||v_branch_digits||v_parent_digits||lpad((coalesce(v_max,0)+1)::text,v_digits,'0');
    new:=jsonb_populate_record(new,jsonb_build_object('warehouse_code',v_code));
    return new;
  end if;
  if tg_table_name='erp_hr_departments' and v_key='section' then
    v_parent_department_id:=nullif(to_jsonb(new)->>'parent_id','')::uuid;
    select p.department_code,p.department_level into v_parent_department_code,v_parent_department_level
    from public.erp_hr_departments p where p.id=v_parent_department_id and p.company_id=v_company and p.is_active=true;
    if not found then raise exception 'اختر إدارة أو قسمًا رئيسيًا نشطًا لإنشاء القسم'; end if;
    if v_parent_department_level not in ('directorate','department') then raise exception 'لا يمكن إنشاء قسم فرعي تحت قسم فرعي آخر'; end if;
    v_parent_digits:=regexp_replace(v_parent_department_code,'[^0-9]','','g');
    if v_parent_digits='' then raise exception 'كود الإدارة الأب لا يحتوي على أرقام لتوليد كود القسم'; end if;
    if length(v_prefix) <> 3 then raise exception 'بادئة سياسة الأقسام غير صحيحة'; end if;
    if translate(v_prefix,'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz','') <> '' then raise exception 'بادئة سياسة الأقسام يجب أن تكون حروفًا إنجليزية'; end if;
    if v_digits < 1 then raise exception 'عدد خانات سياسة الأقسام غير صحيح'; end if;
    if v_digits > 6 then raise exception 'عدد خانات سياسة الأقسام غير صحيح'; end if;
    v_lock:=v_company::text||':section:'||v_prefix;
    perform pg_advisory_xact_lock(hashtextextended(v_lock,0));
    select coalesce(max(right(d.department_code,v_digits)::bigint),0) into v_max
    from public.erp_hr_departments d where d.company_id=v_company and d.department_level='section' and d.id is distinct from new.id
      and d.department_code ~ ('^'||v_prefix||'[0-9]+[0-9]{'||v_digits||'}$');
    if coalesce(v_max,0)+1>=power(10::numeric,v_digits) then raise exception 'انتهت خانات تسلسل الأقسام؛ زد عدد الخانات من سياسات التكويد'; end if;
    v_code:=v_prefix||v_parent_digits||lpad((coalesce(v_max,0)+1)::text,v_digits,'0');
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

CREATE OR REPLACE FUNCTION private.erp_code_policy_lock_status(p_company_id uuid)
 RETURNS text[]
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
BEGIN
  IF auth.uid() IS NULL OR NOT public.erp_user_can_access_company(p_company_id) THEN
    RAISE EXCEPTION 'غير مصرح بقراءة حالة سياسات التكويد لهذه الشركة';
  END IF;

  RETURN ARRAY(
    SELECT x.policy_key
    FROM (VALUES
      ('code_policy.program_policy', EXISTS(SELECT 1 FROM public.erp_program_policies p WHERE p.company_id=p_company_id AND nullif(p.policy_code,'') IS NOT NULL)),
      ('code_policy.employee', EXISTS(SELECT 1 FROM public.erp_employees t WHERE t.company_id=p_company_id AND nullif(t.employee_code,'') IS NOT NULL)),
      ('code_policy.user', EXISTS(SELECT 1 FROM public.erp_users t WHERE t.company_id=p_company_id AND nullif(t.user_code,'') IS NOT NULL)),
      ('code_policy.supplier', EXISTS(SELECT 1 FROM public.erp_parties t WHERE t.company_id=p_company_id AND t.party_kind='supplier' AND nullif(t.party_code,'') IS NOT NULL)),
      ('code_policy.representative', EXISTS(SELECT 1 FROM public.erp_sales_representatives t WHERE t.company_id=p_company_id AND nullif(t.rep_code,'') IS NOT NULL)),
      ('code_policy.branch', EXISTS(SELECT 1 FROM public.erp_branches t WHERE t.company_id=p_company_id AND nullif(t.branch_code,'') IS NOT NULL)),
      ('code_policy.storage_location', EXISTS(SELECT 1 FROM public.erp_warehouses t WHERE t.company_id=p_company_id AND t.parent_warehouse_id IS NOT NULL AND nullif(t.warehouse_code,'') IS NOT NULL)),
      ('code_policy.department', EXISTS(SELECT 1 FROM public.erp_hr_departments t WHERE t.company_id=p_company_id AND t.department_level <> 'section' AND nullif(t.department_code,'') IS NOT NULL)),
      ('code_policy.section', EXISTS(SELECT 1 FROM public.erp_hr_departments t WHERE t.company_id=p_company_id AND t.department_level = 'section' AND nullif(t.department_code,'') IS NOT NULL)),
      ('code_policy.work_location', EXISTS(SELECT 1 FROM public.erp_hr_work_locations t WHERE t.company_id=p_company_id AND nullif(t.location_code,'') IS NOT NULL)),
      ('code_policy.job', EXISTS(SELECT 1 FROM public.erp_hr_jobs t WHERE t.company_id=p_company_id AND nullif(t.job_code,'') IS NOT NULL)),
      ('code_policy.grade', EXISTS(SELECT 1 FROM public.erp_hr_job_grades t WHERE t.company_id=p_company_id AND nullif(t.grade_code,'') IS NOT NULL)),
      ('code_policy.salary_element', EXISTS(SELECT 1 FROM public.erp_hr_salary_elements t WHERE t.company_id=p_company_id AND nullif(t.element_code,'') IS NOT NULL)),
      ('customer_code', EXISTS(SELECT 1 FROM public.erp_parties t WHERE t.company_id=p_company_id AND t.party_kind='customer' AND nullif(t.party_code,'') IS NOT NULL)),
      ('item_code', EXISTS(SELECT 1 FROM public.erp_items t WHERE t.company_id=p_company_id AND nullif(t.item_code,'') IS NOT NULL)),
      ('code_type.payroll_run', EXISTS(SELECT 1 FROM public.erp_payroll_runs t WHERE t.company_id=p_company_id AND nullif(t.run_code,'') IS NOT NULL)),
      ('code_type.warehouse', EXISTS(SELECT 1 FROM public.erp_warehouses t WHERE t.company_id=p_company_id AND t.parent_warehouse_id IS NULL AND nullif(t.warehouse_code,'') IS NOT NULL)),
      ('code_type.unit', EXISTS(SELECT 1 FROM public.erp_item_unit_catalog t WHERE t.company_id=p_company_id AND nullif(t.unit_code,'') IS NOT NULL)),
      ('code_type.payment_method', EXISTS(SELECT 1 FROM public.erp_payment_methods t WHERE t.company_id=p_company_id AND nullif(t.payment_method_code,'') IS NOT NULL)),
      ('code_type.shift', EXISTS(SELECT 1 FROM public.erp_hr_shifts t WHERE t.company_id=p_company_id AND nullif(t.shift_code,'') IS NOT NULL)),
      ('code_type.commission_plan', EXISTS(SELECT 1 FROM public.erp_commission_plans t WHERE t.company_id=p_company_id AND nullif(t.plan_code,'') IS NOT NULL)),
      ('code_type.sales_fulfillment', EXISTS(SELECT 1 FROM public.erp_sales_fulfillment_documents t WHERE t.company_id=p_company_id AND nullif(t.manual_number,'') IS NOT NULL)),
      ('code_type.user_type', EXISTS(SELECT 1 FROM public.erp_user_types t WHERE t.company_id=p_company_id AND nullif(t.type_code_display,'') IS NOT NULL)),
      ('code_type.permission_template', EXISTS(SELECT 1 FROM public.erp_permission_templates t WHERE t.company_id=p_company_id AND nullif(t.template_code_display,'') IS NOT NULL)),
      ('code_type.user_classification', EXISTS(SELECT 1 FROM public.erp_user_classifications t WHERE t.company_id=p_company_id AND nullif(t.classification_code_display,'') IS NOT NULL)),
      ('code_type.journal_entry', EXISTS(SELECT 1 FROM public.erp_journal_entries t WHERE t.company_id=p_company_id AND nullif(t.entry_number_display,'') IS NOT NULL)),
      ('code_type.account', EXISTS(SELECT 1 FROM public.erp_accounts t WHERE t.company_id=p_company_id AND nullif(t.account_code,'') IS NOT NULL)),
      ('code_type.cashbox', EXISTS(SELECT 1 FROM public.erp_cashboxes t WHERE t.company_id=p_company_id AND nullif(t.cashbox_code,'') IS NOT NULL)),
      ('code_type.cost_center', EXISTS(SELECT 1 FROM public.erp_cost_centers t WHERE t.company_id=p_company_id AND nullif(t.center_code,'') IS NOT NULL)),
      ('code_type.price_list', EXISTS(SELECT 1 FROM public.erp_price_lists t WHERE t.company_id=p_company_id AND nullif(t.price_list_code,'') IS NOT NULL)),
      ('code_type.sales_invoice', EXISTS(SELECT 1 FROM public.erp_sales_documents t WHERE t.company_id=p_company_id AND nullif(t.document_number,'') IS NOT NULL AND coalesce(t.document_type,'') NOT IN ('quotation','order','delivery','return'))),
      ('code_type.sales_order', EXISTS(SELECT 1 FROM public.erp_sales_documents t WHERE t.company_id=p_company_id AND t.document_type='order' AND nullif(t.document_number,'') IS NOT NULL)),
      ('code_type.sales_delivery', EXISTS(SELECT 1 FROM public.erp_sales_documents t WHERE t.company_id=p_company_id AND t.document_type='delivery' AND nullif(t.document_number,'') IS NOT NULL)),
      ('code_type.sales_return', EXISTS(SELECT 1 FROM public.erp_sales_documents t WHERE t.company_id=p_company_id AND t.document_type='return' AND nullif(t.document_number,'') IS NOT NULL)),
      ('code_type.quotation', EXISTS(SELECT 1 FROM public.erp_sales_documents t WHERE t.company_id=p_company_id AND t.document_type='quotation' AND nullif(t.document_number,'') IS NOT NULL)),
      ('code_type.purchase_invoice', EXISTS(SELECT 1 FROM public.erp_purchase_documents t WHERE t.company_id=p_company_id AND nullif(t.document_number,'') IS NOT NULL AND coalesce(t.document_type,'') NOT IN ('order','receipt','return'))),
      ('code_type.purchase_order', EXISTS(SELECT 1 FROM public.erp_purchase_documents t WHERE t.company_id=p_company_id AND t.document_type='order' AND nullif(t.document_number,'') IS NOT NULL)),
      ('code_type.purchase_receipt', EXISTS(SELECT 1 FROM public.erp_purchase_documents t WHERE t.company_id=p_company_id AND t.document_type='receipt' AND nullif(t.document_number,'') IS NOT NULL)),
      ('code_type.purchase_return', EXISTS(SELECT 1 FROM public.erp_purchase_documents t WHERE t.company_id=p_company_id AND t.document_type='return' AND nullif(t.document_number,'') IS NOT NULL)),
      ('code_type.cash_receipt', EXISTS(SELECT 1 FROM public.erp_cash_vouchers t WHERE t.company_id=p_company_id AND coalesce(t.voucher_type,'') NOT IN ('payment','transfer') AND nullif(t.voucher_number,'') IS NOT NULL)),
      ('code_type.cash_payment', EXISTS(SELECT 1 FROM public.erp_cash_vouchers t WHERE t.company_id=p_company_id AND t.voucher_type='payment' AND nullif(t.voucher_number,'') IS NOT NULL)),
      ('code_type.cash_transfer', EXISTS(SELECT 1 FROM public.erp_cash_vouchers t WHERE t.company_id=p_company_id AND t.voucher_type='transfer' AND nullif(t.voucher_number,'') IS NOT NULL)),
      ('code_type.cash_movement', EXISTS(SELECT 1 FROM public.erp_cash_movements t WHERE t.company_id=p_company_id AND nullif(t.movement_number,'') IS NOT NULL)),
      ('code_type.cash_order', EXISTS(SELECT 1 FROM public.erp_cash_orders t WHERE t.company_id=p_company_id AND nullif(t.order_number,'') IS NOT NULL)),
      ('code_type.checkbook', EXISTS(SELECT 1 FROM public.erp_checkbooks t WHERE t.company_id=p_company_id AND nullif(t.book_number,'') IS NOT NULL)),
      ('code_type.fixed_asset', EXISTS(SELECT 1 FROM public.erp_fixed_assets t WHERE t.company_id=p_company_id AND nullif(t.asset_code,'') IS NOT NULL)),
      ('code_type.asset_category', EXISTS(SELECT 1 FROM public.erp_asset_categories t WHERE t.company_id=p_company_id AND nullif(t.category_code,'') IS NOT NULL)),
      ('code_type.asset_depreciation_run', EXISTS(SELECT 1 FROM public.erp_asset_depreciation_runs t WHERE t.company_id=p_company_id AND nullif(t.run_code,'') IS NOT NULL)),
      ('code_type.asset_disposal', EXISTS(SELECT 1 FROM public.erp_asset_disposals t WHERE t.company_id=p_company_id AND nullif(t.disposal_code,'') IS NOT NULL)),
      ('code_type.crm_activity', EXISTS(SELECT 1 FROM public.erp_crm_activities t WHERE t.company_id=p_company_id AND nullif(t.activity_code,'') IS NOT NULL)),
      ('code_type.crm_lead', EXISTS(SELECT 1 FROM public.erp_crm_leads t WHERE t.company_id=p_company_id AND nullif(t.lead_code,'') IS NOT NULL)),
      ('code_type.construction_project', EXISTS(SELECT 1 FROM public.erp_construction_projects t WHERE t.company_id=p_company_id AND nullif(t.project_code,'') IS NOT NULL)),
      ('code_type.construction_material_request', EXISTS(SELECT 1 FROM public.erp_construction_material_requests t WHERE t.company_id=p_company_id AND nullif(t.request_code,'') IS NOT NULL)),
      ('code_type.construction_payment_certificate', EXISTS(SELECT 1 FROM public.erp_construction_payment_certificates t WHERE t.company_id=p_company_id AND nullif(t.certificate_number,'') IS NOT NULL)),
      ('code_type.construction_site_report', EXISTS(SELECT 1 FROM public.erp_construction_site_reports t WHERE t.company_id=p_company_id AND nullif(t.report_code,'') IS NOT NULL)),
      ('code_type.construction_material_movement', EXISTS(SELECT 1 FROM public.erp_construction_material_movements t WHERE t.company_id=p_company_id AND nullif(t.movement_code,'') IS NOT NULL)),
      ('code_type.manufacturing_bom', EXISTS(SELECT 1 FROM public.erp_manufacturing_boms t WHERE t.company_id=p_company_id AND nullif(t.bom_code,'') IS NOT NULL)),
      ('code_type.manufacturing_work_center', EXISTS(SELECT 1 FROM public.erp_manufacturing_work_centers t WHERE t.company_id=p_company_id AND nullif(t.center_code,'') IS NOT NULL)),
      ('code_type.production_order', EXISTS(SELECT 1 FROM public.erp_production_orders t WHERE t.company_id=p_company_id AND nullif(t.order_code,'') IS NOT NULL)),
      ('code_type.production_quality_check', EXISTS(SELECT 1 FROM public.erp_production_quality_checks t WHERE t.company_id=p_company_id AND nullif(t.inspection_code,'') IS NOT NULL)),
      ('code_type.production_variance', EXISTS(SELECT 1 FROM public.erp_production_variances t WHERE t.company_id=p_company_id AND nullif(t.variance_code,'') IS NOT NULL)),
      ('code_type.service_ticket', EXISTS(SELECT 1 FROM public.erp_service_tickets t WHERE t.company_id=p_company_id AND nullif(t.ticket_code,'') IS NOT NULL)),
      ('code_type.service_visit', EXISTS(SELECT 1 FROM public.erp_service_visits t WHERE t.company_id=p_company_id AND nullif(t.visit_code,'') IS NOT NULL)),
      ('code_type.hr_contract', EXISTS(SELECT 1 FROM public.erp_hr_employee_contracts t WHERE t.company_id=p_company_id AND nullif(t.contract_number,'') IS NOT NULL)),
      ('code_type.hr_advance', EXISTS(SELECT 1 FROM public.erp_hr_employee_advances t WHERE t.company_id=p_company_id AND nullif(t.advance_number,'') IS NOT NULL)),
      ('code_type.hr_custody', EXISTS(SELECT 1 FROM public.erp_hr_employee_custodies t WHERE t.company_id=p_company_id AND nullif(t.custody_code,'') IS NOT NULL)),
      ('code_type.service_sla_policy', EXISTS(SELECT 1 FROM public.erp_service_sla_policies t WHERE t.company_id=p_company_id AND nullif(t.policy_code,'') IS NOT NULL)),
      ('code_type.business_suite_record', EXISTS(SELECT 1 FROM public.erp_business_suite_records t WHERE t.company_id=p_company_id AND nullif(t.record_code,'') IS NOT NULL)),
      ('code_type.workspace_branch', EXISTS(SELECT 1 FROM public.erp_business_workspace_branches t JOIN public.erp_business_workspaces w ON w.id=t.workspace_id WHERE w.platform_company_id=p_company_id AND nullif(t.branch_code,'') IS NOT NULL)),
      ('code_type.workspace_cash_movement', EXISTS(SELECT 1 FROM public.erp_business_workspace_cash_movements t JOIN public.erp_business_workspaces w ON w.id=t.workspace_id WHERE w.platform_company_id=p_company_id AND nullif(t.movement_no,'') IS NOT NULL)),
      ('code_type.workspace_customer', EXISTS(SELECT 1 FROM public.erp_business_workspace_counterparties t JOIN public.erp_business_workspaces w ON w.id=t.workspace_id WHERE w.platform_company_id=p_company_id AND t.party_type='customer' AND nullif(t.party_code,'') IS NOT NULL)),
      ('code_type.workspace_supplier', EXISTS(SELECT 1 FROM public.erp_business_workspace_counterparties t JOIN public.erp_business_workspaces w ON w.id=t.workspace_id WHERE w.platform_company_id=p_company_id AND t.party_type='supplier' AND nullif(t.party_code,'') IS NOT NULL)),
      ('code_type.workspace_department', EXISTS(SELECT 1 FROM public.erp_business_workspace_departments t JOIN public.erp_business_workspaces w ON w.id=t.workspace_id WHERE w.platform_company_id=p_company_id AND nullif(t.department_code,'') IS NOT NULL)),
      ('code_type.workspace_employee', EXISTS(SELECT 1 FROM public.erp_business_workspace_employees t JOIN public.erp_business_workspaces w ON w.id=t.workspace_id WHERE w.platform_company_id=p_company_id AND nullif(t.employee_code,'') IS NOT NULL)),
      ('code_type.workspace_warehouse', EXISTS(SELECT 1 FROM public.erp_business_workspace_warehouses t JOIN public.erp_business_workspaces w ON w.id=t.workspace_id WHERE w.platform_company_id=p_company_id AND nullif(t.warehouse_code,'') IS NOT NULL)),
      ('code_type.workspace_purchase', EXISTS(SELECT 1 FROM public.erp_business_workspace_documents t JOIN public.erp_business_workspaces w ON w.id=t.workspace_id WHERE w.platform_company_id=p_company_id AND t.document_type='purchase' AND nullif(t.document_no,'') IS NOT NULL)),
      ('code_type.workspace_purchase_return', EXISTS(SELECT 1 FROM public.erp_business_workspace_documents t JOIN public.erp_business_workspaces w ON w.id=t.workspace_id WHERE w.platform_company_id=p_company_id AND t.document_type='purchase_return' AND nullif(t.document_no,'') IS NOT NULL)),
      ('code_type.workspace_sale', EXISTS(SELECT 1 FROM public.erp_business_workspace_documents t JOIN public.erp_business_workspaces w ON w.id=t.workspace_id WHERE w.platform_company_id=p_company_id AND t.document_type='sale' AND nullif(t.document_no,'') IS NOT NULL)),
      ('code_type.workspace_sale_return', EXISTS(SELECT 1 FROM public.erp_business_workspace_documents t JOIN public.erp_business_workspaces w ON w.id=t.workspace_id WHERE w.platform_company_id=p_company_id AND t.document_type='sale_return' AND nullif(t.document_no,'') IS NOT NULL)),
      ('code_type.workspace_transfer', EXISTS(SELECT 1 FROM public.erp_business_workspace_documents t JOIN public.erp_business_workspaces w ON w.id=t.workspace_id WHERE w.platform_company_id=p_company_id AND t.document_type='transfer' AND nullif(t.document_no,'') IS NOT NULL)),
      ('code_type.workspace_adjustment', EXISTS(SELECT 1 FROM public.erp_business_workspace_documents t JOIN public.erp_business_workspaces w ON w.id=t.workspace_id WHERE w.platform_company_id=p_company_id AND t.document_type='adjustment' AND nullif(t.document_no,'') IS NOT NULL)),
      ('code_type.workspace_item_link', EXISTS(SELECT 1 FROM public.erp_business_workspace_item_links t JOIN public.erp_business_workspaces w ON w.id=t.workspace_id WHERE w.platform_company_id=p_company_id AND nullif(t.local_code,'') IS NOT NULL))
    ) AS x(policy_key, has_code)
    WHERE x.has_code
    ORDER BY x.policy_key
  );
END;
$function$
;

CREATE OR REPLACE FUNCTION public.erp_preview_next_central_code(p_company_id uuid, p_entity_key text)
 RETURNS text
 LANGUAGE plpgsql
 SET search_path TO ''
AS $function$
declare
  v_table text;
  v_column text;
  v_prefix text;
  v_digits integer;
  v_policy_prefix text;
  v_policy_digits integer;
  v_max bigint;
  v_workspace_scoped boolean := false;
begin
  if auth.uid() is null or not public.erp_user_can_access_company(p_company_id) then
    raise exception 'غير مصرح بمعاينة أكواد هذه الشركة';
  end if;

  case p_entity_key
    when 'employee' then v_table := 'erp_employees'; v_column := 'employee_code'; v_prefix := 'Emp';
    when 'user' then v_table := 'erp_users'; v_column := 'user_code'; v_prefix := 'Usr';
    when 'user_type' then v_table := 'erp_user_types'; v_column := 'type_code_display'; v_prefix := 'Typ';
    when 'permission_template' then v_table := 'erp_permission_templates'; v_column := 'template_code_display'; v_prefix := 'Tpl';
    when 'branch' then v_table := 'erp_branches'; v_column := 'branch_code'; v_prefix := 'Brn';
    when 'warehouse' then v_table := 'erp_warehouses'; v_column := 'warehouse_code'; v_prefix := 'Whs';
    when 'category' then v_table := 'erp_item_categories'; v_column := 'category_code'; v_prefix := 'Cat';
    when 'cost_center' then v_table := 'erp_cost_centers'; v_column := 'center_code'; v_prefix := 'Cst';
    when 'price_list' then v_table := 'erp_price_lists'; v_column := 'price_list_code'; v_prefix := 'Pli';
    when 'account' then v_table := 'erp_accounts'; v_column := 'account_code'; v_prefix := 'Acc';
    when 'cashbox' then v_table := 'erp_cashboxes'; v_column := 'cashbox_code'; v_prefix := 'Csh';
    when 'supplier' then v_table := 'erp_parties'; v_column := 'party_code'; v_prefix := 'Ven';
    when 'customer' then v_table := 'erp_parties'; v_column := 'party_code'; v_prefix := 'Cus';
    when 'department' then v_table := 'erp_hr_departments'; v_column := 'department_code'; v_prefix := 'Dep';
    when 'job' then v_table := 'erp_hr_jobs'; v_column := 'job_code'; v_prefix := 'Job';
    when 'work_location' then v_table := 'erp_hr_work_locations'; v_column := 'location_code'; v_prefix := 'Plc';
    when 'grade' then v_table := 'erp_hr_job_grades'; v_column := 'grade_code'; v_prefix := 'Grd';
    when 'payroll_run' then v_table := 'erp_payroll_runs'; v_column := 'run_code'; v_prefix := 'Prl';
    when 'salary_element' then v_table := 'erp_hr_salary_elements'; v_column := 'element_code'; v_prefix := 'Elm';
    when 'unit' then v_table := 'erp_item_unit_catalog'; v_column := 'unit_code'; v_prefix := 'Unt';
    when 'payment_method' then v_table := 'erp_payment_methods'; v_column := 'payment_method_code'; v_prefix := 'Pmt';
    when 'shift' then v_table := 'erp_hr_shifts'; v_column := 'shift_code'; v_prefix := 'Shf';
    when 'commission_plan' then v_table := 'erp_commission_plans'; v_column := 'plan_code'; v_prefix := 'Com';
    when 'sales_fulfillment' then v_table := 'erp_sales_fulfillment_documents'; v_column := 'manual_number'; v_prefix := 'Ful';
    when 'user_classification' then v_table := 'erp_user_classifications'; v_column := 'classification_code_display'; v_prefix := 'Cls';
    when 'journal_entry' then v_table := 'erp_journal_entries'; v_column := 'entry_number_display'; v_prefix := 'Jrn';
    when 'delegate' then v_table := 'erp_sales_representatives'; v_column := 'rep_code'; v_prefix := 'Rep';
    when 'sales_invoice' then v_table := 'erp_sales_documents'; v_column := 'document_number'; v_prefix := 'Siv';
    when 'sales_order' then v_table := 'erp_sales_documents'; v_column := 'document_number'; v_prefix := 'Sor';
    when 'quotation' then v_table := 'erp_sales_documents'; v_column := 'document_number'; v_prefix := 'Qot';
    when 'sales_delivery' then v_table := 'erp_sales_documents'; v_column := 'document_number'; v_prefix := 'Dlv';
    when 'sales_return' then v_table := 'erp_sales_documents'; v_column := 'document_number'; v_prefix := 'Srt';
    when 'purchase_invoice' then v_table := 'erp_purchase_documents'; v_column := 'document_number'; v_prefix := 'Piv';
    when 'purchase_order' then v_table := 'erp_purchase_documents'; v_column := 'document_number'; v_prefix := 'Por';
    when 'purchase_receipt' then v_table := 'erp_purchase_documents'; v_column := 'document_number'; v_prefix := 'Prr';
    when 'purchase_return' then v_table := 'erp_purchase_documents'; v_column := 'document_number'; v_prefix := 'Prt';
    when 'cash_receipt' then v_table := 'erp_cash_vouchers'; v_column := 'voucher_number'; v_prefix := 'Rcp';
    when 'cash_payment' then v_table := 'erp_cash_vouchers'; v_column := 'voucher_number'; v_prefix := 'Cpy';
    when 'cash_transfer' then v_table := 'erp_cash_vouchers'; v_column := 'voucher_number'; v_prefix := 'Trf';
    when 'checkbook' then v_table := 'erp_checkbooks'; v_column := 'book_number'; v_prefix := 'Ckb';
    when 'cash_movement' then v_table := 'erp_cash_movements'; v_column := 'movement_number'; v_prefix := 'Cmv';
    when 'cash_order' then v_table := 'erp_cash_orders'; v_column := 'order_number'; v_prefix := 'Cso';
    when 'workspace_branch' then v_table := 'erp_business_workspace_branches'; v_column := 'branch_code'; v_prefix := 'Wbr'; v_workspace_scoped := true;
    when 'workspace_cash_movement' then v_table := 'erp_business_workspace_cash_movements'; v_column := 'movement_no'; v_prefix := 'Wcm'; v_workspace_scoped := true;
    when 'workspace_customer' then v_table := 'erp_business_workspace_counterparties'; v_column := 'party_code'; v_prefix := 'Wcu'; v_workspace_scoped := true;
    when 'workspace_supplier' then v_table := 'erp_business_workspace_counterparties'; v_column := 'party_code'; v_prefix := 'Wsu'; v_workspace_scoped := true;
    when 'workspace_department' then v_table := 'erp_business_workspace_departments'; v_column := 'department_code'; v_prefix := 'Wdp'; v_workspace_scoped := true;
    when 'workspace_employee' then v_table := 'erp_business_workspace_employees'; v_column := 'employee_code'; v_prefix := 'Wem'; v_workspace_scoped := true;
    when 'workspace_warehouse' then v_table := 'erp_business_workspace_warehouses'; v_column := 'warehouse_code'; v_prefix := 'Wwh'; v_workspace_scoped := true;
    when 'workspace_purchase' then v_table := 'erp_business_workspace_documents'; v_column := 'document_no'; v_prefix := 'Wpi'; v_workspace_scoped := true;
    when 'workspace_purchase_return' then v_table := 'erp_business_workspace_documents'; v_column := 'document_no'; v_prefix := 'Wpr'; v_workspace_scoped := true;
    when 'workspace_sale' then v_table := 'erp_business_workspace_documents'; v_column := 'document_no'; v_prefix := 'Wsi'; v_workspace_scoped := true;
    when 'workspace_sale_return' then v_table := 'erp_business_workspace_documents'; v_column := 'document_no'; v_prefix := 'Wsr'; v_workspace_scoped := true;
    when 'workspace_transfer' then v_table := 'erp_business_workspace_documents'; v_column := 'document_no'; v_prefix := 'Wtr'; v_workspace_scoped := true;
    when 'workspace_adjustment' then v_table := 'erp_business_workspace_documents'; v_column := 'document_no'; v_prefix := 'Wad'; v_workspace_scoped := true;
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
  v_digits := coalesce(v_policy_digits, case p_entity_key when 'customer' then 4 when 'branch' then 3 when 'department' then 3 when 'work_location' then 3 when 'grade' then 3 when 'salary_element' then 3 when 'user_type' then 2 when 'permission_template' then 3 else 5 end);
  if v_prefix !~ '^[A-Za-z]{3}$' or v_digits < 1 or v_digits > 12 then
    raise exception 'إعدادات التكويد غير صحيحة';
  end if;
  if to_regclass('public.' || v_table) is null then
    raise exception 'جدول نوع التكويد غير متاح';
  end if;
  if v_workspace_scoped then
    execute format(
      'select coalesce(max(substring(t.%I from %L)::bigint), 0) from public.%I t join public.erp_business_workspaces w on w.id = t.workspace_id where w.platform_company_id = $1 and t.%I ~ $2',
      v_column, '^' || v_prefix || '([0-9]+)$', v_table, v_column
    ) into v_max using p_company_id, '^' || v_prefix || '[0-9]+$';
  else
    execute format(
      'select coalesce(max(substring(%I from %L)::bigint), 0) from public.%I where company_id = $1 and %I ~ $2',
      v_column, '^' || v_prefix || '([0-9]+)$', v_table, v_column
    ) into v_max using p_company_id, '^' || v_prefix || '[0-9]+$';
  end if;
  if coalesce(v_max, 0) + 1 >= power(10::numeric, v_digits) then
    raise exception 'انتهت خانات الكود؛ زد عدد الخانات من سياسات التكويد';
  end if;
  return v_prefix || lpad((coalesce(v_max, 0) + 1)::text, v_digits, '0');
end;
$function$
;

CREATE OR REPLACE FUNCTION public.erp_assign_customer_geo_code()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
DECLARE
  v_geo_hierarchical_code text;
  v_geo_code text;
  v_geo_prefix text := 'Rig';
  v_country_code text;
  v_policy jsonb := '{}'::jsonb;
  v_lengths jsonb := '{}'::jsonb;
  v_segments jsonb := '{}'::jsonb;
  v_prefix text := 'Cus';
  v_digits integer := 4;
  v_geo_digits integer;
  v_area_id uuid;
  v_max bigint;
  v_lock text;
BEGIN
  IF coalesce(NEW.party_kind,'')<>'customer' THEN
    RETURN NEW;
  END IF;

  IF TG_OP='UPDATE' THEN
    IF NEW.geographic_area_id IS NOT DISTINCT FROM OLD.geographic_area_id
       AND nullif(NEW.party_code,'') IS NOT NULL THEN
      RETURN NEW;
    END IF;
  ELSIF nullif(NEW.party_code,'') IS NOT NULL THEN
    RETURN NEW;
  END IF;

  v_area_id:=NEW.geographic_area_id;
  IF v_area_id IS NULL THEN
    RAISE EXCEPTION 'اختيار المنطقة مطلوب لتوليد كود العميل المرتبط بالتقسيم الجغرافي';
  END IF;

  SELECT CASE WHEN left(p.policy_value,1)='{' THEN p.policy_value::jsonb ELSE '{}'::jsonb END
    INTO v_policy
  FROM public.erp_program_policies p
  WHERE p.company_id=NEW.company_id AND p.policy_key='code_generation_registry'
  LIMIT 1;
  v_geo_prefix:=coalesce(nullif(v_policy->>'geo_prefix',''),'Rig');
  v_lengths:=coalesce(v_policy->'geo_segment_lengths','{}'::jsonb);
  v_segments:=coalesce(v_policy->'geo_segments','{}'::jsonb);

  SELECT c.country_code INTO v_country_code
  FROM public.erp_countries c
  WHERE c.company_id=NEW.company_id AND c.name_ar='مصر' AND c.is_active=true
  ORDER BY c.created_at LIMIT 1;

  IF v_country_code IS NULL OR length(v_country_code)<>2 OR v_country_code !~ '^[0-9]+' THEN
    RAISE EXCEPTION 'كود مصر يجب أن يكون رقمين لتوليد كود العميل';
  END IF;

  IF v_lengths='{}'::jsonb THEN
    v_lengths:=jsonb_build_object(
      'governorate',coalesce(nullif(v_segments->>'governorate','')::integer - length(v_country_code),2),
      'center',coalesce(nullif(v_segments->>'center','')::integer - nullif(v_segments->>'governorate','')::integer,2),
      'area',coalesce(nullif(v_segments->>'area','')::integer - nullif(v_segments->>'center','')::integer,2)
    );
  END IF;

  v_geo_digits:=length(v_country_code)
    +coalesce(nullif(v_lengths->>'governorate','')::integer,2)
    +coalesce(nullif(v_lengths->>'center','')::integer,2)
    +coalesce(nullif(v_lengths->>'area','')::integer,2);

  SELECT g.hierarchical_code INTO v_geo_hierarchical_code
  FROM public.erp_geographic_data g
  WHERE g.id=v_area_id
    AND g.company_id=NEW.company_id
    AND g.level='area'
    AND g.is_active=true;

  v_geo_code:=regexp_replace(coalesce(v_geo_hierarchical_code,''),'[^0-9]','','g');
  IF v_geo_hierarchical_code IS NULL
     OR left(v_geo_hierarchical_code,length(v_geo_prefix))<>v_geo_prefix
     OR length(v_geo_code)<>v_geo_digits THEN
    RAISE EXCEPTION 'المنطقة المختارة لا تحتوي على كود Rig مطابق لأطوال سياسات التكويد (% أرقام)',v_geo_digits;
  END IF;

  SELECT c.prefix,c.digits INTO v_prefix,v_digits
  FROM public.erp_code_policy_config(NEW.company_id,'customer','Cus',4) c;

  IF length(v_prefix)<1 OR length(v_prefix)>10 OR v_prefix !~ '^[A-Za-z]+'
     OR v_prefix ~ '[^A-Za-z]' OR v_digits<1 OR v_digits>12 THEN
    RAISE EXCEPTION 'إعدادات كود العميل غير صحيحة';
  END IF;

  v_lock:=NEW.company_id::text||':customer:'||v_area_id::text;
  PERFORM pg_advisory_xact_lock(hashtextextended(v_lock,0));

  SELECT coalesce(max(substring(p.party_code from length(v_prefix||v_geo_code)+1)::bigint),0)
    INTO v_max
  FROM public.erp_parties p
  WHERE p.company_id=NEW.company_id
    AND p.party_kind='customer'
    AND p.geographic_area_id=v_area_id
    AND p.id IS DISTINCT FROM NEW.id
    AND left(p.party_code,length(v_prefix||v_geo_code))=v_prefix||v_geo_code
    AND length(p.party_code)=length(v_prefix||v_geo_code)+v_digits
    AND substring(p.party_code from length(v_prefix||v_geo_code)+1) ~ '^[0-9]+';

  IF coalesce(v_max,0)+1>=power(10::numeric,v_digits) THEN
    RAISE EXCEPTION 'انتهت خانات تسلسل العملاء داخل هذه المنطقة؛ زد عدد الخانات من سياسات التكويد';
  END IF;

  NEW.party_code:=v_prefix||v_geo_code||lpad((coalesce(v_max,0)+1)::text,v_digits,'0');
  RETURN NEW;
END;
$function$
;

CREATE OR REPLACE FUNCTION public.erp_preview_next_customer_geo_code(p_company_id uuid, p_geo_area_id uuid)
 RETURNS text
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
DECLARE
  v_geo_hierarchical_code text;
  v_geo_code text;
  v_geo_prefix text := 'Rig';
  v_country_code text;
  v_policy jsonb := '{}'::jsonb;
  v_lengths jsonb := '{}'::jsonb;
  v_segments jsonb := '{}'::jsonb;
  v_geo_digits integer;
  v_prefix text := 'Cus';
  v_digits integer := 4;
  v_max bigint;
BEGIN
  IF auth.uid() IS NULL OR NOT public.erp_user_can_access_company(p_company_id) THEN
    RAISE EXCEPTION 'غير مصرح بمعاينة أكواد هذه الشركة';
  END IF;

  SELECT CASE WHEN left(p.policy_value,1)='{' THEN p.policy_value::jsonb ELSE '{}'::jsonb END
    INTO v_policy
  FROM public.erp_program_policies p
  WHERE p.company_id=p_company_id AND p.policy_key='code_generation_registry'
  LIMIT 1;
  v_geo_prefix:=coalesce(nullif(v_policy->>'geo_prefix',''),'Rig');
  v_lengths:=coalesce(v_policy->'geo_segment_lengths','{}'::jsonb);
  v_segments:=coalesce(v_policy->'geo_segments','{}'::jsonb);

  SELECT c.country_code INTO v_country_code
  FROM public.erp_countries c
  WHERE c.company_id=p_company_id AND c.name_ar='مصر' AND c.is_active=true
  ORDER BY c.created_at LIMIT 1;

  IF v_country_code IS NULL OR length(v_country_code)<>2 OR v_country_code !~ '^[0-9]+' THEN
    RAISE EXCEPTION 'كود مصر يجب أن يكون رقمين لمعاينة كود العميل';
  END IF;

  IF v_lengths='{}'::jsonb THEN
    v_lengths:=jsonb_build_object(
      'governorate',coalesce(nullif(v_segments->>'governorate','')::integer - length(v_country_code),2),
      'center',coalesce(nullif(v_segments->>'center','')::integer - nullif(v_segments->>'governorate','')::integer,2),
      'area',coalesce(nullif(v_segments->>'area','')::integer - nullif(v_segments->>'center','')::integer,2)
    );
  END IF;

  v_geo_digits:=length(v_country_code)
    +coalesce(nullif(v_lengths->>'governorate','')::integer,2)
    +coalesce(nullif(v_lengths->>'center','')::integer,2)
    +coalesce(nullif(v_lengths->>'area','')::integer,2);

  SELECT g.hierarchical_code INTO v_geo_hierarchical_code
  FROM public.erp_geographic_data g
  WHERE g.id=p_geo_area_id AND g.company_id=p_company_id AND g.level='area' AND g.is_active=true;

  v_geo_code:=regexp_replace(coalesce(v_geo_hierarchical_code,''),'[^0-9]','','g');
  IF v_geo_hierarchical_code IS NULL
     OR left(v_geo_hierarchical_code,length(v_geo_prefix))<>v_geo_prefix
     OR length(v_geo_code)<>v_geo_digits THEN
    RAISE EXCEPTION 'اختر منطقة فعالة لها كود Rig مطابق لأطوال سياسة التكويد';
  END IF;

  SELECT c.prefix,c.digits INTO v_prefix,v_digits
  FROM public.erp_code_policy_config(p_company_id,'customer','Cus',4) c;

  SELECT coalesce(max(substring(p.party_code from length(v_prefix||v_geo_code)+1)::bigint),0)
    INTO v_max
  FROM public.erp_parties p
  WHERE p.company_id=p_company_id
    AND p.party_kind='customer'
    AND p.geographic_area_id=p_geo_area_id
    AND left(p.party_code,length(v_prefix||v_geo_code))=v_prefix||v_geo_code
    AND length(p.party_code)=length(v_prefix||v_geo_code)+v_digits
    AND substring(p.party_code from length(v_prefix||v_geo_code)+1) ~ '^[0-9]+';

  RETURN v_prefix||v_geo_code||lpad((coalesce(v_max,0)+1)::text,v_digits,'0');
END;
$function$
;

CREATE OR REPLACE FUNCTION public.erp_set_permission_template_display_code()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare p text; d integer;
begin
  select prefix, digits into p, d
  from public.erp_code_policy_config(new.company_id, 'permission_template', 'Tpl', 3);
  new.template_code_display := p || lpad(new.template_code::text, d, '0');
  return new;
end;
$function$
;

UPDATE public.erp_program_policies
SET policy_value=jsonb_set(policy_value::jsonb,'{inheritance}',to_jsonb('يرث أرقام الفرع والمخزن بدون البادئتين، مع تسلسل عام على مستوى الشركة لمنع التكرار'::text),true)::text,updated_at=now()
WHERE policy_key='code_policy.storage_location' AND left(policy_value,1)='{';

UPDATE public.erp_program_policies
SET policy_value=jsonb_set(policy_value::jsonb,'{inheritance}',to_jsonb('يرث أرقام الإدارة بدون البادئة، مع تسلسل عام على مستوى الشركة لمنع التكرار'::text),true)::text,updated_at=now()
WHERE policy_key='code_policy.section' AND left(policy_value,1)='{';
COMMIT;
