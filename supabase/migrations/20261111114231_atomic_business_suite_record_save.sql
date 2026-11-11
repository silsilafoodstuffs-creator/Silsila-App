CREATE OR REPLACE FUNCTION public.erp_save_business_suite_record(p_parent jsonb, p_plan jsonb DEFAULT '{}'::jsonb)
 RETURNS jsonb
 LANGUAGE plpgsql
 SET search_path TO ''
AS $function$
DECLARE
  v_user_id uuid := auth.uid();
  v_company_id uuid;
  v_parent_id uuid;
  v_existing_operational_id uuid;
  v_operational_id uuid;
  v_table text;
  v_module_key text;
  v_record_type text;
  v_data jsonb;
  v_actions jsonb;
  v_action jsonb;
  v_action_type text;
  v_action_count integer := 0;
  v_allowed_columns text[];
  v_conflict_columns text[];
  v_write_columns text[];
  v_insert_columns text;
  v_select_expressions text;
  v_update_assignments text;
  v_upsert_assignments text;
  v_conflict_sql text;
  v_parent_details jsonb;
BEGIN
  IF v_user_id IS NULL THEN
    RAISE EXCEPTION 'يلزم تسجيل الدخول قبل حفظ السجل' USING ERRCODE = '28000';
  END IF;

  IF p_parent IS NULL OR jsonb_typeof(p_parent) <> 'object' THEN
    RAISE EXCEPTION 'بيانات السجل العام غير صالحة' USING ERRCODE = '22023';
  END IF;

  IF p_plan IS NULL OR jsonb_typeof(p_plan) <> 'object' THEN
    RAISE EXCEPTION 'خطة الحفظ التشغيلي غير صالحة' USING ERRCODE = '22023';
  END IF;

  IF EXISTS (
    SELECT 1
    FROM jsonb_object_keys(p_parent) AS x(key)
    WHERE x.key <> ALL (ARRAY[
      'id','company_id','module_key','record_type','record_code','name',
      'status','record_date','due_date','counterparty','amount','quantity',
      'details'
    ]::text[])
  ) THEN
    RAISE EXCEPTION 'تحتوي بيانات السجل العام على حقول غير مسموح بها' USING ERRCODE = '22023';
  END IF;

  IF EXISTS (
    SELECT 1
    FROM jsonb_object_keys(p_plan) AS x(key)
    WHERE x.key <> ALL (ARRAY['table','id','data','actions']::text[])
  ) THEN
    RAISE EXCEPTION 'تحتوي خطة الحفظ على خصائص غير مسموح بها' USING ERRCODE = '22023';
  END IF;

  v_company_id := NULLIF(p_parent->>'company_id', '')::uuid;
  v_module_key := NULLIF(BTRIM(p_parent->>'module_key'), '');
  v_record_type := NULLIF(BTRIM(p_parent->>'record_type'), '');

  IF v_company_id IS NULL OR v_module_key IS NULL OR v_record_type IS NULL
     OR NULLIF(BTRIM(p_parent->>'record_code'), '') IS NULL
     OR NULLIF(BTRIM(p_parent->>'name'), '') IS NULL THEN
    RAISE EXCEPTION 'الشركة ونوع السجل والكود والاسم حقول إلزامية' USING ERRCODE = '22023';
  END IF;

  IF v_module_key <> ALL (ARRAY['fixed_assets','manufacturing','contracting','customer_service']::text[]) THEN
    RAISE EXCEPTION 'مجموعة السجل غير معتمدة' USING ERRCODE = '22023';
  END IF;

  IF jsonb_typeof(COALESCE(p_parent->'details','{}'::jsonb)) <> 'object' THEN
    RAISE EXCEPTION 'تفاصيل السجل يجب أن تكون كائن JSON' USING ERRCODE = '22023';
  END IF;

  v_parent_id := NULLIF(p_parent->>'id', '')::uuid;
  IF v_parent_id IS NOT NULL THEN
    PERFORM 1
    FROM public.erp_business_suite_records r
    WHERE r.id = v_parent_id
      AND r.company_id = v_company_id
    FOR UPDATE;

    IF NOT FOUND THEN
      RAISE EXCEPTION 'السجل العام غير موجود أو لا تملك صلاحية تعديله داخل الشركة' USING ERRCODE = '42501';
    END IF;
  END IF;

  v_table := NULLIF(BTRIM(p_plan->>'table'), '');
  v_existing_operational_id := NULLIF(p_plan->>'id', '')::uuid;
  v_actions := COALESCE(p_plan->'actions', '[]'::jsonb);

  IF jsonb_typeof(v_actions) <> 'array' THEN
    RAISE EXCEPTION 'الإجراءات التابعة يجب أن تكون قائمة' USING ERRCODE = '22023';
  END IF;

  v_action_count := jsonb_array_length(v_actions);
  IF v_action_count > 8 THEN
    RAISE EXCEPTION 'عدد الإجراءات التابعة يتجاوز الحد المسموح' USING ERRCODE = '22023';
  END IF;

  IF v_table IS NOT NULL THEN
    v_data := p_plan->'data';

    IF v_data IS NULL OR jsonb_typeof(v_data) <> 'object' THEN
      RAISE EXCEPTION 'بيانات السجل التشغيلي غير صالحة' USING ERRCODE = '22023';
    END IF;

    IF NULLIF(v_data->>'company_id','')::uuid IS DISTINCT FROM v_company_id THEN
      RAISE EXCEPTION 'الشركة في السجل التشغيلي لا تطابق الشركة في السجل العام' USING ERRCODE = '23514';
    END IF;

    CASE v_table
      WHEN 'erp_asset_categories' THEN
        v_allowed_columns := ARRAY['company_id','category_code','name','depreciation_method','useful_life_months','residual_percent','asset_account_id','accumulated_account_id','expense_account_id','is_active'];
        v_conflict_columns := ARRAY['company_id','category_code'];
      WHEN 'erp_fixed_assets' THEN
        v_allowed_columns := ARRAY['company_id','category_id','asset_code','name','serial_number','acquisition_date','in_service_date','acquisition_cost','residual_value','useful_life_months','depreciation_method','accumulated_depreciation','location','custodian','supplier_name','purchase_reference','asset_account_id','accumulated_account_id','expense_account_id','status'];
        v_conflict_columns := ARRAY['company_id','asset_code'];
      WHEN 'erp_asset_depreciation_runs' THEN
        v_allowed_columns := ARRAY['company_id','run_code','period_start','period_end','total_amount','status'];
        v_conflict_columns := ARRAY['company_id','run_code'];
      WHEN 'erp_asset_disposals' THEN
        v_allowed_columns := ARRAY['company_id','asset_id','disposal_code','disposal_date','disposal_method','reason','buyer','book_value','proceeds','cash_account_id','gain_loss_account_id','status'];
        v_conflict_columns := ARRAY['company_id','disposal_code'];
      WHEN 'erp_asset_movements' THEN
        v_allowed_columns := ARRAY['company_id','asset_id','movement_type','suite_record_code','reference','movement_date','from_location','to_location','from_custodian','to_custodian','condition_note','status'];
        v_conflict_columns := ARRAY['company_id','suite_record_code'];
      WHEN 'erp_manufacturing_boms' THEN
        v_allowed_columns := ARRAY['company_id','bom_code','product_id','product_name','output_quantity','output_unit','version','scrap_percent','status','effective_from','effective_to'];
        v_conflict_columns := ARRAY['company_id','bom_code','version'];
      WHEN 'erp_manufacturing_work_centers' THEN
        v_allowed_columns := ARRAY['company_id','center_code','name','center_type','capacity_per_hour','hourly_cost','setup_minutes','location','supervisor','is_active'];
        v_conflict_columns := ARRAY['company_id','center_code'];
      WHEN 'erp_production_variances' THEN
        v_allowed_columns := ARRAY['company_id','variance_code','production_order_id','item_id','item_name','variance_type','quantity','unit','unit_cost','reason','movement_date'];
        v_conflict_columns := ARRAY['company_id','variance_code'];
      WHEN 'erp_production_quality_checks' THEN
        v_allowed_columns := ARRAY['company_id','inspection_code','production_order_id','inspection_stage','parameter_name','measured_value','minimum_value','maximum_value','result','inspected_quantity','rejected_quantity','inspector','notes'];
        v_conflict_columns := ARRAY['company_id','inspection_code'];
      WHEN 'erp_production_orders' THEN
        v_allowed_columns := ARRAY['company_id','order_code','product_id','product_name','planned_quantity','produced_quantity','scrap_quantity','planned_start','planned_end','status','estimated_cost','actual_cost','actual_hours','lot_number','notes','warehouse_id','bom_id','work_center_id'];
        v_conflict_columns := ARRAY['company_id','order_code'];
      WHEN 'erp_construction_material_requests' THEN
        v_allowed_columns := ARRAY['company_id','request_code','project_id','requested_date','required_date','requested_by','priority','status','notes'];
        v_conflict_columns := ARRAY['company_id','request_code'];
      WHEN 'erp_construction_material_movements' THEN
        v_allowed_columns := ARRAY['company_id','movement_code','project_id','item_id','item_name','warehouse_id','movement_type','quantity','unit','unit_cost','movement_date','notes'];
        v_conflict_columns := ARRAY['company_id','movement_code'];
      WHEN 'erp_construction_boq_lines' THEN
        v_allowed_columns := ARRAY['company_id','project_id','suite_record_code','item_code','description','unit','planned_quantity','unit_rate','executed_quantity','approved_quantity','line_order','notes'];
        v_conflict_columns := ARRAY['company_id','suite_record_code'];
      WHEN 'erp_construction_costs' THEN
        v_allowed_columns := ARRAY['company_id','project_id','boq_line_id','suite_record_code','cost_date','cost_type','description','quantity','unit_cost','amount','supplier_name','document_reference','status'];
        v_conflict_columns := ARRAY['company_id','suite_record_code'];
      WHEN 'erp_construction_site_reports' THEN
        v_allowed_columns := ARRAY['company_id','project_id','report_code','report_date','engineer','weather','labor_count','equipment','materials','work_done','issues','safety','status'];
        v_conflict_columns := ARRAY['company_id','report_code'];
      WHEN 'erp_construction_projects' THEN
        v_allowed_columns := ARRAY['company_id','project_code','name','customer_id','site_address','project_type','contract_number','contract_value','budget_amount','actual_cost','progress_percent','planned_start','planned_end','status','project_manager','retention_percent','notes'];
        v_conflict_columns := ARRAY['company_id','project_code'];
      WHEN 'erp_construction_payment_certificates' THEN
        v_allowed_columns := ARRAY['company_id','project_id','certificate_number','period_start','period_end','gross_amount','retention_amount','advance_recovery','deductions','status','notes'];
        v_conflict_columns := ARRAY['company_id','certificate_number'];
      WHEN 'erp_crm_leads' THEN
        v_allowed_columns := ARRAY['company_id','lead_code','title','party_id','contact_name','phone','email','source','stage','probability','expected_revenue','expected_close_date','next_activity','status'];
        v_conflict_columns := ARRAY['company_id','lead_code'];
      WHEN 'erp_service_sla_policies' THEN
        v_allowed_columns := ARRAY['company_id','policy_code','name','priority','first_response_minutes','resolution_minutes','escalation_minutes','is_active'];
        v_conflict_columns := ARRAY['company_id','policy_code'];
      WHEN 'erp_service_tickets' THEN
        v_allowed_columns := ARRAY['company_id','ticket_code','subject','description','party_id','sla_policy_id','channel','category','priority','status','team_name','resolution','satisfaction_score','first_response_due_at','resolution_due_at','escalation_due_at','updated_at','first_responded_at','resolved_at','closed_at'];
        v_conflict_columns := ARRAY['company_id','ticket_code'];
      WHEN 'erp_service_visits' THEN
        v_allowed_columns := ARRAY['company_id','visit_code','ticket_id','scheduled_at','address','visit_type','status','labor_minutes','materials','outcome','customer_signature_reference'];
        v_conflict_columns := ARRAY['company_id','visit_code'];
      WHEN 'erp_crm_activities' THEN
        v_allowed_columns := ARRAY['company_id','activity_code','activity_type','subject','ticket_id','lead_id','scheduled_at','outcome','next_step','status'];
        v_conflict_columns := ARRAY['company_id','activity_code'];
      ELSE
        RAISE EXCEPTION 'جدول السجل التشغيلي غير مدرج في قائمة الربط المعتمدة' USING ERRCODE = '22023';
    END CASE;

    IF NOT (
      (v_module_key = 'fixed_assets' AND (
        (v_record_type = 'asset_category' AND v_table = 'erp_asset_categories') OR
        (v_record_type = 'asset' AND v_table = 'erp_fixed_assets') OR
        (v_record_type = 'depreciation' AND v_table = 'erp_asset_depreciation_runs') OR
        (v_record_type = 'asset_disposal' AND v_table = 'erp_asset_disposals') OR
        (v_record_type = 'asset_movement' AND v_table = 'erp_asset_movements')
      )) OR
      (v_module_key = 'manufacturing' AND (
        (v_record_type = 'bom' AND v_table = 'erp_manufacturing_boms') OR
        (v_record_type = 'work_center' AND v_table = 'erp_manufacturing_work_centers') OR
        (v_record_type = 'production_variance' AND v_table = 'erp_production_variances') OR
        (v_record_type = 'production_quality_check' AND v_table = 'erp_production_quality_checks') OR
        (v_record_type = 'production_order' AND v_table = 'erp_production_orders')
      )) OR
      (v_module_key = 'contracting' AND (
        (v_record_type = 'material_request' AND v_table = 'erp_construction_material_requests') OR
        (v_record_type = 'material_movement' AND v_table = 'erp_construction_material_movements') OR
        (v_record_type = 'boq' AND v_table = 'erp_construction_boq_lines') OR
        (v_record_type = 'construction_cost' AND v_table = 'erp_construction_costs') OR
        (v_record_type = 'site_report' AND v_table = 'erp_construction_site_reports') OR
        (v_record_type = 'project' AND v_table = 'erp_construction_projects') OR
        (v_record_type = 'certificate' AND v_table = 'erp_construction_payment_certificates')
      )) OR
      (v_module_key = 'customer_service' AND (
        (v_record_type = 'opportunity' AND v_table = 'erp_crm_leads') OR
        (v_record_type = 'sla_policy' AND v_table = 'erp_service_sla_policies') OR
        (v_record_type = 'ticket' AND v_table = 'erp_service_tickets') OR
        (v_record_type = 'field_task' AND v_table = 'erp_service_visits') OR
        (v_record_type = 'activity' AND v_table = 'erp_crm_activities')
      ))
    ) THEN
      RAISE EXCEPTION 'نوع السجل لا يطابق جدول التشغيل المعتمد لهذه المجموعة' USING ERRCODE = '23514';
    END IF;

    IF EXISTS (
      SELECT 1 FROM jsonb_object_keys(v_data) AS x(key)
      WHERE NOT (x.key = ANY(v_allowed_columns))
    ) THEN
      RAISE EXCEPTION 'تحتوي بيانات التشغيل على أعمدة غير مسموح بها' USING ERRCODE = '22023';
    END IF;

    IF NOT (v_data ? 'company_id') THEN
      RAISE EXCEPTION 'معرّف الشركة مطلوب في بيانات التشغيل' USING ERRCODE = '22023';
    END IF;

    IF EXISTS (
      SELECT 1
      FROM unnest(v_conflict_columns) AS x(column_name)
      WHERE NULLIF(v_data->>x.column_name,'') IS NULL
    ) THEN
      RAISE EXCEPTION 'مفتاح التفرد للسجل التشغيلي غير مكتمل' USING ERRCODE = '22023';
    END IF;

    IF v_table = 'erp_construction_material_movements' THEN
      IF v_existing_operational_id IS NULL THEN
        SELECT public.erp_record_construction_stock_movement(
          v_company_id,
          (v_data->>'project_id')::uuid,
          (v_data->>'warehouse_id')::uuid,
          (v_data->>'item_id')::uuid,
          v_data->>'item_name',
          (v_data->>'quantity')::numeric,
          v_data->>'unit',
          (v_data->>'unit_cost')::numeric,
          (v_data->>'movement_date')::date,
          v_data->>'movement_type',
          v_data->>'movement_code',
          v_data->>'notes'
        )
        INTO v_operational_id;
      ELSE
        SELECT m.id INTO v_operational_id
        FROM public.erp_construction_material_movements m
        WHERE m.id = v_existing_operational_id
          AND m.company_id = v_company_id
          AND m.movement_code = v_data->>'movement_code'
          AND m.project_id = (v_data->>'project_id')::uuid
          AND m.warehouse_id = (v_data->>'warehouse_id')::uuid
          AND m.item_id = (v_data->>'item_id')::uuid
          AND m.movement_type = v_data->>'movement_type'
          AND m.quantity = (v_data->>'quantity')::numeric
          AND m.unit = v_data->>'unit'
          AND m.unit_cost = (v_data->>'unit_cost')::numeric
          AND m.movement_date = (v_data->>'movement_date')::date
        FOR UPDATE;

        IF NOT FOUND THEN
          RAISE EXCEPTION 'حركة المخزون مرحّلة ولا يجوز تعديلها؛ أنشئ حركة عكسية أو جديدة' USING ERRCODE = '23514';
        END IF;
      END IF;
    ELSE
      SELECT array_agg(x.column_name ORDER BY x.ordinality)
      INTO v_write_columns
      FROM unnest(v_allowed_columns) WITH ORDINALITY AS x(column_name, ordinality)
      WHERE v_data ? x.column_name;

      IF v_write_columns IS NULL OR NOT ('company_id' = ANY(v_write_columns)) THEN
        RAISE EXCEPTION 'لا توجد أعمدة صالحة للحفظ التشغيلي' USING ERRCODE = '22023';
      END IF;

      SELECT
        string_agg(format('%I', x.column_name), ', ' ORDER BY x.ordinality),
        string_agg(format('(jsonb_populate_record(NULL::public.%I, $1)).%I', v_table, x.column_name), ', ' ORDER BY x.ordinality),
        string_agg(format('%1$I = src.%1$I', x.column_name), ', ' ORDER BY x.ordinality)
          FILTER (WHERE x.column_name <> 'company_id'),
        string_agg(format('%1$I = EXCLUDED.%1$I', x.column_name), ', ' ORDER BY x.ordinality)
          FILTER (WHERE x.column_name <> 'company_id')
      INTO v_insert_columns, v_select_expressions, v_update_assignments, v_upsert_assignments
      FROM unnest(v_write_columns) WITH ORDINALITY AS x(column_name, ordinality);

      SELECT string_agg(format('%I', x.column_name), ', ' ORDER BY x.ordinality)
      INTO v_conflict_sql
      FROM unnest(v_conflict_columns) WITH ORDINALITY AS x(column_name, ordinality);

      IF v_existing_operational_id IS NOT NULL THEN
        IF v_update_assignments IS NULL THEN
          RAISE EXCEPTION 'لا توجد بيانات لتحديث السجل التشغيلي' USING ERRCODE = '22023';
        END IF;

        EXECUTE format(
          'UPDATE public.%I AS t SET %s FROM (SELECT %s) AS src WHERE t.id = $2 AND t.company_id = $3 RETURNING t.id',
          v_table, v_update_assignments, v_select_expressions
        )
        INTO v_operational_id
        USING v_data, v_existing_operational_id, v_company_id;

        IF v_operational_id IS NULL THEN
          RAISE EXCEPTION 'السجل التشغيلي غير موجود داخل الشركة أو لا تملك صلاحية تعديله' USING ERRCODE = '42501';
        END IF;
      ELSE
        IF v_upsert_assignments IS NULL OR v_conflict_sql IS NULL THEN
          RAISE EXCEPTION 'تعذر بناء عملية حفظ آمنة للسجل التشغيلي' USING ERRCODE = '22023';
        END IF;

        EXECUTE format(
          'INSERT INTO public.%I (%s) SELECT %s ON CONFLICT (%s) DO UPDATE SET %s RETURNING id',
          v_table, v_insert_columns, v_select_expressions, v_conflict_sql, v_upsert_assignments
        )
        INTO v_operational_id
        USING v_data;
      END IF;
    END IF;

    IF v_operational_id IS NULL THEN
      RAISE EXCEPTION 'لم يتم الحصول على معرّف السجل التشغيلي بعد الحفظ' USING ERRCODE = 'P0001';
    END IF;
  ELSIF v_action_count > 0 OR p_plan ? 'data' OR p_plan ? 'id' THEN
    RAISE EXCEPTION 'لا يمكن إرسال بيانات أو إجراءات تشغيلية دون تحديد جدول معتمد' USING ERRCODE = '22023';
  END IF;

  FOR v_action IN
    SELECT value FROM jsonb_array_elements(v_actions) AS e(value)
  LOOP
    v_action_type := v_action->>'type';

    CASE v_action_type
      WHEN 'replace_construction_material_request_lines' THEN
        IF v_table <> 'erp_construction_material_requests'
           OR jsonb_typeof(v_action->'p_lines') <> 'array' THEN
          RAISE EXCEPTION 'إجراء تفاصيل طلب المواد غير متوافق مع السجل' USING ERRCODE = '22023';
        END IF;
        PERFORM public.erp_replace_construction_material_request_lines(
          v_company_id, v_operational_id, v_parent_id, v_action->'p_lines'
        );

      WHEN 'finalize_asset_depreciation_run' THEN
        IF v_table <> 'erp_asset_depreciation_runs' THEN
          RAISE EXCEPTION 'إجراء احتساب الإهلاك غير متوافق مع السجل' USING ERRCODE = '22023';
        END IF;
        PERFORM public.erp_finalize_asset_depreciation_run(
          v_company_id, v_operational_id, COALESCE((v_action->>'p_post')::boolean,false)
        );

      WHEN 'sync_construction_certificate_lines' THEN
        IF v_table <> 'erp_construction_payment_certificates'
           OR jsonb_typeof(v_action->'p_lines') <> 'array' THEN
          RAISE EXCEPTION 'إجراء بنود المستخلص غير متوافق مع السجل' USING ERRCODE = '22023';
        END IF;
        PERFORM public.erp_sync_construction_certificate_lines(
          v_company_id, v_operational_id, v_parent_id, v_action->'p_lines',
          COALESCE((v_action->>'p_replace_lines')::boolean,false)
        );

      WHEN 'post_asset_disposal' THEN
        IF v_table <> 'erp_asset_disposals' THEN
          RAISE EXCEPTION 'إجراء ترحيل استبعاد الأصل غير متوافق مع السجل' USING ERRCODE = '22023';
        END IF;
        PERFORM public.erp_post_asset_disposal(v_company_id, v_operational_id);

      WHEN 'sync_production_order_execution' THEN
        IF v_table <> 'erp_production_orders'
           OR jsonb_typeof(COALESCE(v_action->'p_materials','[]'::jsonb)) <> 'array' THEN
          RAISE EXCEPTION 'إجراء تنفيذ أمر التصنيع غير متوافق مع السجل' USING ERRCODE = '22023';
        END IF;
        PERFORM public.erp_sync_production_order_execution(
          v_company_id,
          v_operational_id,
          COALESCE(NULLIF(v_action->>'p_movement_date','')::date,CURRENT_DATE),
          COALESCE((v_action->>'p_sync_materials')::boolean,false),
          COALESCE(v_action->'p_materials','[]'::jsonb),
          COALESCE(NULLIF(v_action->>'p_produced_quantity','')::numeric,0),
          COALESCE(NULLIF(v_action->>'p_actual_hours','')::numeric,0),
          COALESCE(NULLIF(v_action->>'p_actual_cost','')::numeric,0),
          v_action->'p_quality'
        );

      WHEN 'replace_manufacturing_bom_lines' THEN
        IF v_table <> 'erp_manufacturing_boms'
           OR jsonb_typeof(v_action->'p_lines') <> 'array' THEN
          RAISE EXCEPTION 'إجراء مكونات قائمة المواد غير متوافق مع السجل' USING ERRCODE = '22023';
        END IF;
        PERFORM public.erp_replace_manufacturing_bom_lines(
          v_company_id, v_operational_id, v_parent_id, v_action->'p_lines'
        );

      ELSE
        RAISE EXCEPTION 'نوع الإجراء التابع غير معتمد' USING ERRCODE = '22023';
    END CASE;
  END LOOP;

  v_parent_details := COALESCE(p_parent->'details','{}'::jsonb);
  IF v_table IS NOT NULL THEN
    v_parent_details := (v_parent_details - '_operational_table' - '_operational_id')
      || jsonb_build_object('_operational_table',v_table,'_operational_id',v_operational_id);
  END IF;

  IF v_parent_id IS NULL THEN
    INSERT INTO public.erp_business_suite_records(
      company_id,module_key,record_type,record_code,name,status,
      record_date,due_date,counterparty,amount,quantity,details,created_by
    )
    VALUES(
      v_company_id,
      v_module_key,
      v_record_type,
      BTRIM(p_parent->>'record_code'),
      BTRIM(p_parent->>'name'),
      COALESCE(NULLIF(p_parent->>'status',''),'draft'),
      NULLIF(p_parent->>'record_date','')::date,
      NULLIF(p_parent->>'due_date','')::date,
      NULLIF(p_parent->>'counterparty',''),
      COALESCE(NULLIF(p_parent->>'amount','')::numeric,0),
      COALESCE(NULLIF(p_parent->>'quantity','')::numeric,0),
      v_parent_details,
      v_user_id
    )
    RETURNING id INTO v_parent_id;
  ELSE
    UPDATE public.erp_business_suite_records
    SET module_key = v_module_key,
        record_type = v_record_type,
        record_code = BTRIM(p_parent->>'record_code'),
        name = BTRIM(p_parent->>'name'),
        status = COALESCE(NULLIF(p_parent->>'status',''),'draft'),
        record_date = CASE WHEN p_parent ? 'record_date' THEN NULLIF(p_parent->>'record_date','')::date ELSE record_date END,
        due_date = CASE WHEN p_parent ? 'due_date' THEN NULLIF(p_parent->>'due_date','')::date ELSE due_date END,
        counterparty = NULLIF(p_parent->>'counterparty',''),
        amount = CASE WHEN p_parent ? 'amount' THEN COALESCE(NULLIF(p_parent->>'amount','')::numeric,0) ELSE amount END,
        quantity = CASE WHEN p_parent ? 'quantity' THEN COALESCE(NULLIF(p_parent->>'quantity','')::numeric,0) ELSE quantity END,
        details = v_parent_details,
        updated_at = now()
    WHERE id = v_parent_id
      AND company_id = v_company_id
    RETURNING id INTO v_parent_id;

    IF v_parent_id IS NULL THEN
      RAISE EXCEPTION 'تعذر تحديث السجل العام داخل الشركة' USING ERRCODE = '42501';
    END IF;
  END IF;

  RETURN jsonb_build_object(
    'record_id',v_parent_id,
    'operational_table',v_table,
    'operational_id',v_operational_id,
    'details',v_parent_details
  );
END;
$function$

;
REVOKE ALL ON FUNCTION public.erp_save_business_suite_record(jsonb,jsonb) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.erp_save_business_suite_record(jsonb,jsonb) FROM anon;
GRANT EXECUTE ON FUNCTION public.erp_save_business_suite_record(jsonb,jsonb) TO authenticated;
