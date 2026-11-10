CREATE SCHEMA IF NOT EXISTS private;
REVOKE ALL ON SCHEMA private FROM PUBLIC, anon;
GRANT USAGE ON SCHEMA private TO authenticated;

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
      ('code_policy.storage_location', EXISTS(SELECT 1 FROM public.erp_warehouses t WHERE t.company_id=p_company_id AND nullif(t.warehouse_code,'') IS NOT NULL)),
      ('code_policy.department', EXISTS(SELECT 1 FROM public.erp_hr_departments t WHERE t.company_id=p_company_id AND nullif(t.department_code,'') IS NOT NULL)),
      ('code_policy.work_location', EXISTS(SELECT 1 FROM public.erp_hr_work_locations t WHERE t.company_id=p_company_id AND nullif(t.location_code,'') IS NOT NULL)),
      ('code_policy.job', EXISTS(SELECT 1 FROM public.erp_hr_jobs t WHERE t.company_id=p_company_id AND nullif(t.job_code,'') IS NOT NULL)),
      ('code_policy.grade', EXISTS(SELECT 1 FROM public.erp_hr_job_grades t WHERE t.company_id=p_company_id AND nullif(t.grade_code,'') IS NOT NULL)),
      ('code_policy.salary_element', EXISTS(SELECT 1 FROM public.erp_hr_salary_elements t WHERE t.company_id=p_company_id AND nullif(t.element_code,'') IS NOT NULL)),
      ('customer_code', EXISTS(SELECT 1 FROM public.erp_parties t WHERE t.company_id=p_company_id AND t.party_kind='customer' AND nullif(t.party_code,'') IS NOT NULL)),
      ('item_code', EXISTS(SELECT 1 FROM public.erp_items t WHERE t.company_id=p_company_id AND nullif(t.item_code,'') IS NOT NULL)),
      ('code_type.payroll_run', EXISTS(SELECT 1 FROM public.erp_payroll_runs t WHERE t.company_id=p_company_id AND nullif(t.run_code,'') IS NOT NULL)),
      ('code_type.warehouse', EXISTS(SELECT 1 FROM public.erp_warehouses t WHERE t.company_id=p_company_id AND nullif(t.warehouse_code,'') IS NOT NULL)),
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
$function$;

CREATE OR REPLACE FUNCTION private.erp_preview_next_extended_central_code(p_company_id uuid, p_entity_key text)
RETURNS text
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO ''
AS $function$
DECLARE
  v_table text;
  v_column text;
  v_default_prefix text;
  v_default_digits integer := 5;
  v_prefix text;
  v_digits integer;
  v_max bigint;
BEGIN
  IF auth.uid() IS NULL OR NOT public.erp_user_can_access_company(p_company_id) THEN
    RAISE EXCEPTION 'غير مصرح بمعاينة أكواد هذه الشركة';
  END IF;

  CASE p_entity_key
    WHEN 'fixed_asset' THEN v_table := 'erp_fixed_assets'; v_column := 'asset_code'; v_default_prefix := 'Ast';
    WHEN 'asset_category' THEN v_table := 'erp_asset_categories'; v_column := 'category_code'; v_default_prefix := 'Aca'; v_default_digits := 3;
    WHEN 'asset_depreciation_run' THEN v_table := 'erp_asset_depreciation_runs'; v_column := 'run_code'; v_default_prefix := 'Adr';
    WHEN 'asset_disposal' THEN v_table := 'erp_asset_disposals'; v_column := 'disposal_code'; v_default_prefix := 'Adp';
    WHEN 'crm_activity' THEN v_table := 'erp_crm_activities'; v_column := 'activity_code'; v_default_prefix := 'Act';
    WHEN 'crm_lead' THEN v_table := 'erp_crm_leads'; v_column := 'lead_code'; v_default_prefix := 'Led';
    WHEN 'construction_project' THEN v_table := 'erp_construction_projects'; v_column := 'project_code'; v_default_prefix := 'Cpj';
    WHEN 'construction_material_request' THEN v_table := 'erp_construction_material_requests'; v_column := 'request_code'; v_default_prefix := 'Cmr';
    WHEN 'construction_payment_certificate' THEN v_table := 'erp_construction_payment_certificates'; v_column := 'certificate_number'; v_default_prefix := 'Cpc';
    WHEN 'construction_site_report' THEN v_table := 'erp_construction_site_reports'; v_column := 'report_code'; v_default_prefix := 'Csr';
    WHEN 'construction_material_movement' THEN v_table := 'erp_construction_material_movements'; v_column := 'movement_code'; v_default_prefix := 'Cmm';
    WHEN 'manufacturing_bom' THEN v_table := 'erp_manufacturing_boms'; v_column := 'bom_code'; v_default_prefix := 'Mfb';
    WHEN 'manufacturing_work_center' THEN v_table := 'erp_manufacturing_work_centers'; v_column := 'center_code'; v_default_prefix := 'Mwc'; v_default_digits := 4;
    WHEN 'production_order' THEN v_table := 'erp_production_orders'; v_column := 'order_code'; v_default_prefix := 'Pdo';
    WHEN 'production_quality_check' THEN v_table := 'erp_production_quality_checks'; v_column := 'inspection_code'; v_default_prefix := 'Pqc';
    WHEN 'production_variance' THEN v_table := 'erp_production_variances'; v_column := 'variance_code'; v_default_prefix := 'Pvr';
    WHEN 'service_ticket' THEN v_table := 'erp_service_tickets'; v_column := 'ticket_code'; v_default_prefix := 'Svt';
    WHEN 'service_visit' THEN v_table := 'erp_service_visits'; v_column := 'visit_code'; v_default_prefix := 'Svs';
    WHEN 'hr_contract' THEN v_table := 'erp_hr_employee_contracts'; v_column := 'contract_number'; v_default_prefix := 'Hct';
    WHEN 'hr_advance' THEN v_table := 'erp_hr_employee_advances'; v_column := 'advance_number'; v_default_prefix := 'Hav';
    WHEN 'hr_custody' THEN v_table := 'erp_hr_employee_custodies'; v_column := 'custody_code'; v_default_prefix := 'Hcy';
    WHEN 'service_sla_policy' THEN v_table := 'erp_service_sla_policies'; v_column := 'policy_code'; v_default_prefix := 'Slp'; v_default_digits := 4;
    WHEN 'business_suite_record' THEN v_table := 'erp_business_suite_records'; v_column := 'record_code'; v_default_prefix := 'Bsr';
    ELSE RAISE EXCEPTION 'نوع التكويد الممتد غير مدعوم: %', p_entity_key;
  END CASE;

  SELECT c.prefix, c.digits INTO v_prefix, v_digits
  FROM public.erp_code_policy_config(p_company_id, p_entity_key, v_default_prefix, v_default_digits) c;

  EXECUTE format(
    'SELECT coalesce(max(substring(%I from %L)::bigint), 0) FROM public.%I WHERE company_id = $1 AND %I ~ $2',
    v_column, '^' || v_prefix || '([0-9]+)$', v_table, v_column
  )
  INTO v_max
  USING p_company_id, '^' || v_prefix || '[0-9]+$';

  IF coalesce(v_max, 0) + 1 >= power(10::numeric, v_digits) THEN
    RAISE EXCEPTION 'انتهت خانات الكود؛ زد عدد الخانات من سياسات التكويد';
  END IF;

  RETURN v_prefix || lpad((coalesce(v_max, 0) + 1)::text, v_digits, '0');
END;
$function$;

REVOKE ALL ON FUNCTION private.erp_code_policy_lock_status(uuid) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION private.erp_code_policy_lock_status(uuid) TO authenticated;

REVOKE ALL ON FUNCTION private.erp_preview_next_extended_central_code(uuid, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION private.erp_preview_next_extended_central_code(uuid, text) TO authenticated;

CREATE OR REPLACE FUNCTION public.erp_code_policy_lock_status(p_company_id uuid)
RETURNS text[]
LANGUAGE sql
SECURITY INVOKER
SET search_path TO ''
AS $wrapper$
  SELECT private.erp_code_policy_lock_status(p_company_id);
$wrapper$;

CREATE OR REPLACE FUNCTION public.erp_preview_next_extended_central_code(p_company_id uuid, p_entity_key text)
RETURNS text
LANGUAGE sql
SECURITY INVOKER
SET search_path TO ''
AS $wrapper$
  SELECT private.erp_preview_next_extended_central_code(p_company_id, p_entity_key);
$wrapper$;

REVOKE ALL ON FUNCTION public.erp_code_policy_lock_status(uuid) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.erp_code_policy_lock_status(uuid) TO authenticated;

REVOKE ALL ON FUNCTION public.erp_preview_next_extended_central_code(uuid, text) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.erp_preview_next_extended_central_code(uuid, text) TO authenticated;
