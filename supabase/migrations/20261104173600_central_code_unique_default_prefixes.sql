-- Keep the database defaults aligned with the unique code prefixes shown in the policy editor.
begin;
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
    when 'erp_cash_movements' then v_key := 'cash_movement'; v_column := 'movement_number';
    when 'erp_cash_orders' then v_key := 'cash_order'; v_column := 'order_number';
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
      when 'price_list' then 'Pli'
      when 'account' then 'Acc'
      when 'cashbox' then 'Csh'
      when 'supplier' then 'Sup'
      when 'customer' then 'Cus'
      when 'department' then 'Dpt'
      when 'job' then 'Job'
      when 'work_location' then 'Loc'
      when 'grade' then 'Grd'
      when 'payroll_run' then 'Prl'
      when 'salary_element' then 'Sal'
      when 'unit' then 'Unt'
      when 'payment_method' then 'Pmt'
      when 'shift' then 'Shf'
      when 'commission_plan' then 'Com'
      when 'sales_fulfillment' then 'Ful'
      when 'user_classification' then 'Cls'
      when 'journal_entry' then 'Jrn'
      when 'delegate' then 'Del'
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
      when 'cash_movement' then 'Cmv'
      when 'cash_order' then 'Cso'
      else 'Gen'
    end, 5
  ) c;

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
$$;
revoke all on function public.erp_assign_central_code() from public, anon, authenticated;
create or replace function public.erp_preview_next_central_code(
  p_company_id uuid, p_entity_key text
)
returns text
language plpgsql security invoker set search_path = '' as $$
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
    when 'user_type' then v_table := 'erp_user_types'; v_column := 'type_code_display'; v_prefix := 'Typ';
    when 'permission_template' then v_table := 'erp_permission_templates'; v_column := 'template_code_display'; v_prefix := 'Tpl';
    when 'branch' then v_table := 'erp_branches'; v_column := 'branch_code'; v_prefix := 'Brn';
    when 'warehouse' then v_table := 'erp_warehouses'; v_column := 'warehouse_code'; v_prefix := 'Whs';
    when 'category' then v_table := 'erp_item_categories'; v_column := 'category_code'; v_prefix := 'Cat';
    when 'cost_center' then v_table := 'erp_cost_centers'; v_column := 'center_code'; v_prefix := 'Cst';
    when 'price_list' then v_table := 'erp_price_lists'; v_column := 'price_list_code'; v_prefix := 'Pli';
    when 'account' then v_table := 'erp_accounts'; v_column := 'account_code'; v_prefix := 'Acc';
    when 'cashbox' then v_table := 'erp_cashboxes'; v_column := 'cashbox_code'; v_prefix := 'Csh';
    when 'supplier' then v_table := 'erp_parties'; v_column := 'party_code'; v_prefix := 'Sup';
    when 'customer' then v_table := 'erp_parties'; v_column := 'party_code'; v_prefix := 'Cus';
    when 'department' then v_table := 'erp_hr_departments'; v_column := 'department_code'; v_prefix := 'Dpt';
    when 'job' then v_table := 'erp_hr_jobs'; v_column := 'job_code'; v_prefix := 'Job';
    when 'work_location' then v_table := 'erp_hr_work_locations'; v_column := 'location_code'; v_prefix := 'Loc';
    when 'grade' then v_table := 'erp_hr_job_grades'; v_column := 'grade_code'; v_prefix := 'Grd';
    when 'payroll_run' then v_table := 'erp_payroll_runs'; v_column := 'run_code'; v_prefix := 'Prl';
    when 'salary_element' then v_table := 'erp_hr_salary_elements'; v_column := 'element_code'; v_prefix := 'Sal';
    when 'unit' then v_table := 'erp_item_unit_catalog'; v_column := 'unit_code'; v_prefix := 'Unt';
    when 'payment_method' then v_table := 'erp_payment_methods'; v_column := 'payment_method_code'; v_prefix := 'Pmt';
    when 'shift' then v_table := 'erp_hr_shifts'; v_column := 'shift_code'; v_prefix := 'Shf';
    when 'commission_plan' then v_table := 'erp_commission_plans'; v_column := 'plan_code'; v_prefix := 'Com';
    when 'sales_fulfillment' then v_table := 'erp_sales_fulfillment_documents'; v_column := 'manual_number'; v_prefix := 'Ful';
    when 'user_classification' then v_table := 'erp_user_classifications'; v_column := 'classification_code_display'; v_prefix := 'Cls';
    when 'journal_entry' then v_table := 'erp_journal_entries'; v_column := 'entry_number_display'; v_prefix := 'Jrn';
    when 'delegate' then v_table := 'erp_sales_representatives'; v_column := 'rep_code'; v_prefix := 'Del';
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
    when 'cash_movement' then v_table := 'erp_cash_movements'; v_column := 'movement_number'; v_prefix := 'Cmv';
    when 'cash_order' then v_table := 'erp_cash_orders'; v_column := 'order_number'; v_prefix := 'Cso';
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
  if v_prefix !~ '^[A-Za-z]{3}$' or v_digits < 1 or v_digits > 12 then
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
revoke all on function public.erp_preview_next_central_code(uuid,text) from public, anon;
grant execute on function public.erp_preview_next_central_code(uuid,text) to authenticated;
commit;
