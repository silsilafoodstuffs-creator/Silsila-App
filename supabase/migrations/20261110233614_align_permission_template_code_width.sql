-- Applied migration 20261110233614: match permission-template code width to Program Policies (Tpl + 5 digits)
BEGIN;
CREATE OR REPLACE FUNCTION public.erp_set_permission_template_display_code()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare p text; d integer;
begin
  select prefix, digits into p, d
  from public.erp_code_policy_config(new.company_id, 'permission_template', 'Tpl', 5);
  new.template_code_display := p || lpad(new.template_code::text, d, '0');
  return new;
end;
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
  v_digits := coalesce(v_policy_digits, case p_entity_key when 'customer' then 4 when 'branch' then 3 when 'department' then 3 when 'work_location' then 3 when 'grade' then 3 when 'salary_element' then 3 when 'user_type' then 2 when 'permission_template' then 5 else 5 end);
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
COMMIT;
