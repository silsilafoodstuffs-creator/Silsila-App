-- Central automatic coding for the remaining ERP code-bearing entities.
-- Existing values are preserved; new rows receive codes before NOT NULL checks.

CREATE OR REPLACE FUNCTION public.erp_assign_extended_central_code()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO ''
AS $function$
DECLARE
  v_company uuid;
  v_key text;
  v_column text;
  v_prefix text;
  v_digits integer;
  v_default_prefix text;
  v_default_digits integer := 5;
  v_max bigint;
  v_lock text;
BEGIN
  v_company := (to_jsonb(NEW)->>'company_id')::uuid;
  IF v_company IS NULL THEN
    RAISE EXCEPTION 'company_id مطلوب لتوليد الكود';
  END IF;

  CASE TG_TABLE_NAME
    WHEN 'erp_fixed_assets' THEN v_key := 'fixed_asset'; v_column := 'asset_code'; v_default_prefix := 'Ast';
    WHEN 'erp_asset_categories' THEN v_key := 'asset_category'; v_column := 'category_code'; v_default_prefix := 'Aca'; v_default_digits := 3;
    WHEN 'erp_asset_depreciation_runs' THEN v_key := 'asset_depreciation_run'; v_column := 'run_code'; v_default_prefix := 'Adr';
    WHEN 'erp_asset_disposals' THEN v_key := 'asset_disposal'; v_column := 'disposal_code'; v_default_prefix := 'Adp';
    WHEN 'erp_crm_activities' THEN v_key := 'crm_activity'; v_column := 'activity_code'; v_default_prefix := 'Act';
    WHEN 'erp_crm_leads' THEN v_key := 'crm_lead'; v_column := 'lead_code'; v_default_prefix := 'Led';
    WHEN 'erp_construction_projects' THEN v_key := 'construction_project'; v_column := 'project_code'; v_default_prefix := 'Cpj';
    WHEN 'erp_construction_material_requests' THEN v_key := 'construction_material_request'; v_column := 'request_code'; v_default_prefix := 'Cmr';
    WHEN 'erp_construction_payment_certificates' THEN v_key := 'construction_payment_certificate'; v_column := 'certificate_number'; v_default_prefix := 'Cpc';
    WHEN 'erp_construction_site_reports' THEN v_key := 'construction_site_report'; v_column := 'report_code'; v_default_prefix := 'Csr';
    WHEN 'erp_construction_material_movements' THEN v_key := 'construction_material_movement'; v_column := 'movement_code'; v_default_prefix := 'Cmm';
    WHEN 'erp_manufacturing_boms' THEN v_key := 'manufacturing_bom'; v_column := 'bom_code'; v_default_prefix := 'Mfb';
    WHEN 'erp_manufacturing_work_centers' THEN v_key := 'manufacturing_work_center'; v_column := 'center_code'; v_default_prefix := 'Mwc'; v_default_digits := 4;
    WHEN 'erp_production_orders' THEN v_key := 'production_order'; v_column := 'order_code'; v_default_prefix := 'Pdo';
    WHEN 'erp_production_quality_checks' THEN v_key := 'production_quality_check'; v_column := 'inspection_code'; v_default_prefix := 'Pqc';
    WHEN 'erp_production_variances' THEN v_key := 'production_variance'; v_column := 'variance_code'; v_default_prefix := 'Pvr';
    WHEN 'erp_service_tickets' THEN v_key := 'service_ticket'; v_column := 'ticket_code'; v_default_prefix := 'Svt';
    WHEN 'erp_service_visits' THEN v_key := 'service_visit'; v_column := 'visit_code'; v_default_prefix := 'Svs';
    WHEN 'erp_hr_employee_contracts' THEN v_key := 'hr_contract'; v_column := 'contract_number'; v_default_prefix := 'Hct';
    WHEN 'erp_hr_employee_advances' THEN v_key := 'hr_advance'; v_column := 'advance_number'; v_default_prefix := 'Hav';
    WHEN 'erp_hr_employee_custodies' THEN v_key := 'hr_custody'; v_column := 'custody_code'; v_default_prefix := 'Hcy';
    WHEN 'erp_service_sla_policies' THEN v_key := 'service_sla_policy'; v_column := 'policy_code'; v_default_prefix := 'Slp'; v_default_digits := 4;
    WHEN 'erp_business_suite_records' THEN v_key := 'business_suite_record'; v_column := 'record_code'; v_default_prefix := 'Bsr';
    ELSE RAISE EXCEPTION 'نوع سجل غير مدعوم في التكويد المركزي الممتد: %', TG_TABLE_NAME;
  END CASE;

  IF nullif(to_jsonb(NEW)->>v_column, '') IS NOT NULL THEN
    RETURN NEW;
  END IF;

  SELECT c.prefix, c.digits
    INTO v_prefix, v_digits
  FROM public.erp_code_policy_config(v_company, v_key, v_default_prefix, v_default_digits) c;

  v_lock := v_company::text || ':' || TG_TABLE_NAME || ':' || v_prefix;
  PERFORM pg_advisory_xact_lock(hashtextextended(v_lock, 0));

  EXECUTE format(
    'SELECT coalesce(max(substring(%I from %L)::bigint), 0) FROM public.%I WHERE company_id = $1 AND %I ~ $2',
    v_column, '^' || v_prefix || '([0-9]+)$', TG_TABLE_NAME, v_column
  )
  INTO v_max
  USING v_company, '^' || v_prefix || '[0-9]+$';

  IF coalesce(v_max, 0) + 1 >= power(10::numeric, v_digits) THEN
    RAISE EXCEPTION 'انتهت خانات الكود للنوع %؛ زد عدد الخانات من سياسات التكويد', v_key;
  END IF;

  NEW := jsonb_populate_record(
    NEW,
    jsonb_build_object(v_column, v_prefix || lpad((coalesce(v_max, 0) + 1)::text, v_digits, '0'))
  );
  RETURN NEW;
END;
$function$;

-- Add the same policy-driven generator to every existing entity with a real
-- company-scoped code column that was not covered by the original trigger.
DROP TRIGGER IF EXISTS erp_fixed_assets_central_code ON public.erp_fixed_assets;
CREATE TRIGGER erp_fixed_assets_central_code BEFORE INSERT ON public.erp_fixed_assets
FOR EACH ROW EXECUTE FUNCTION public.erp_assign_extended_central_code();

DROP TRIGGER IF EXISTS erp_asset_categories_central_code ON public.erp_asset_categories;
CREATE TRIGGER erp_asset_categories_central_code BEFORE INSERT ON public.erp_asset_categories
FOR EACH ROW EXECUTE FUNCTION public.erp_assign_extended_central_code();

DROP TRIGGER IF EXISTS erp_asset_depreciation_runs_central_code ON public.erp_asset_depreciation_runs;
CREATE TRIGGER erp_asset_depreciation_runs_central_code BEFORE INSERT ON public.erp_asset_depreciation_runs
FOR EACH ROW EXECUTE FUNCTION public.erp_assign_extended_central_code();

DROP TRIGGER IF EXISTS erp_asset_disposals_central_code ON public.erp_asset_disposals;
CREATE TRIGGER erp_asset_disposals_central_code BEFORE INSERT ON public.erp_asset_disposals
FOR EACH ROW EXECUTE FUNCTION public.erp_assign_extended_central_code();

DROP TRIGGER IF EXISTS erp_crm_activities_central_code ON public.erp_crm_activities;
CREATE TRIGGER erp_crm_activities_central_code BEFORE INSERT ON public.erp_crm_activities
FOR EACH ROW EXECUTE FUNCTION public.erp_assign_extended_central_code();

DROP TRIGGER IF EXISTS erp_crm_leads_central_code ON public.erp_crm_leads;
CREATE TRIGGER erp_crm_leads_central_code BEFORE INSERT ON public.erp_crm_leads
FOR EACH ROW EXECUTE FUNCTION public.erp_assign_extended_central_code();

DROP TRIGGER IF EXISTS erp_construction_projects_central_code ON public.erp_construction_projects;
CREATE TRIGGER erp_construction_projects_central_code BEFORE INSERT ON public.erp_construction_projects
FOR EACH ROW EXECUTE FUNCTION public.erp_assign_extended_central_code();

DROP TRIGGER IF EXISTS erp_construction_material_requests_central_code ON public.erp_construction_material_requests;
CREATE TRIGGER erp_construction_material_requests_central_code BEFORE INSERT ON public.erp_construction_material_requests
FOR EACH ROW EXECUTE FUNCTION public.erp_assign_extended_central_code();

DROP TRIGGER IF EXISTS erp_construction_payment_certificates_central_code ON public.erp_construction_payment_certificates;
CREATE TRIGGER erp_construction_payment_certificates_central_code BEFORE INSERT ON public.erp_construction_payment_certificates
FOR EACH ROW EXECUTE FUNCTION public.erp_assign_extended_central_code();

DROP TRIGGER IF EXISTS erp_construction_site_reports_central_code ON public.erp_construction_site_reports;
CREATE TRIGGER erp_construction_site_reports_central_code BEFORE INSERT ON public.erp_construction_site_reports
FOR EACH ROW EXECUTE FUNCTION public.erp_assign_extended_central_code();

DROP TRIGGER IF EXISTS erp_construction_material_movements_central_code ON public.erp_construction_material_movements;
CREATE TRIGGER erp_construction_material_movements_central_code BEFORE INSERT ON public.erp_construction_material_movements
FOR EACH ROW EXECUTE FUNCTION public.erp_assign_extended_central_code();

DROP TRIGGER IF EXISTS erp_manufacturing_boms_central_code ON public.erp_manufacturing_boms;
CREATE TRIGGER erp_manufacturing_boms_central_code BEFORE INSERT ON public.erp_manufacturing_boms
FOR EACH ROW EXECUTE FUNCTION public.erp_assign_extended_central_code();

DROP TRIGGER IF EXISTS erp_manufacturing_work_centers_central_code ON public.erp_manufacturing_work_centers;
CREATE TRIGGER erp_manufacturing_work_centers_central_code BEFORE INSERT ON public.erp_manufacturing_work_centers
FOR EACH ROW EXECUTE FUNCTION public.erp_assign_extended_central_code();

DROP TRIGGER IF EXISTS erp_production_orders_central_code ON public.erp_production_orders;
CREATE TRIGGER erp_production_orders_central_code BEFORE INSERT ON public.erp_production_orders
FOR EACH ROW EXECUTE FUNCTION public.erp_assign_extended_central_code();

DROP TRIGGER IF EXISTS erp_production_quality_checks_central_code ON public.erp_production_quality_checks;
CREATE TRIGGER erp_production_quality_checks_central_code BEFORE INSERT ON public.erp_production_quality_checks
FOR EACH ROW EXECUTE FUNCTION public.erp_assign_extended_central_code();

DROP TRIGGER IF EXISTS erp_production_variances_central_code ON public.erp_production_variances;
CREATE TRIGGER erp_production_variances_central_code BEFORE INSERT ON public.erp_production_variances
FOR EACH ROW EXECUTE FUNCTION public.erp_assign_extended_central_code();

DROP TRIGGER IF EXISTS erp_service_tickets_central_code ON public.erp_service_tickets;
CREATE TRIGGER erp_service_tickets_central_code BEFORE INSERT ON public.erp_service_tickets
FOR EACH ROW EXECUTE FUNCTION public.erp_assign_extended_central_code();

DROP TRIGGER IF EXISTS erp_service_visits_central_code ON public.erp_service_visits;
CREATE TRIGGER erp_service_visits_central_code BEFORE INSERT ON public.erp_service_visits
FOR EACH ROW EXECUTE FUNCTION public.erp_assign_extended_central_code();

DROP TRIGGER IF EXISTS erp_hr_employee_contracts_central_code ON public.erp_hr_employee_contracts;
CREATE TRIGGER erp_hr_employee_contracts_central_code BEFORE INSERT ON public.erp_hr_employee_contracts
FOR EACH ROW EXECUTE FUNCTION public.erp_assign_extended_central_code();

DROP TRIGGER IF EXISTS erp_hr_employee_advances_central_code ON public.erp_hr_employee_advances;
CREATE TRIGGER erp_hr_employee_advances_central_code BEFORE INSERT ON public.erp_hr_employee_advances
FOR EACH ROW EXECUTE FUNCTION public.erp_assign_extended_central_code();

DROP TRIGGER IF EXISTS erp_hr_employee_custodies_central_code ON public.erp_hr_employee_custodies;
CREATE TRIGGER erp_hr_employee_custodies_central_code BEFORE INSERT ON public.erp_hr_employee_custodies
FOR EACH ROW EXECUTE FUNCTION public.erp_assign_extended_central_code();

DROP TRIGGER IF EXISTS erp_service_sla_policies_central_code ON public.erp_service_sla_policies;
CREATE TRIGGER erp_service_sla_policies_central_code BEFORE INSERT ON public.erp_service_sla_policies
FOR EACH ROW EXECUTE FUNCTION public.erp_assign_extended_central_code();

DROP TRIGGER IF EXISTS erp_business_suite_records_central_code ON public.erp_business_suite_records;
CREATE TRIGGER erp_business_suite_records_central_code BEFORE INSERT ON public.erp_business_suite_records
FOR EACH ROW EXECUTE FUNCTION public.erp_assign_extended_central_code();

-- Workspace item links use workspace_id rather than company_id.
CREATE OR REPLACE FUNCTION public.erp_assign_workspace_item_link_code()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO ''
AS $function$
DECLARE
  v_company uuid;
  v_workspace uuid;
  v_prefix text;
  v_digits integer;
  v_max bigint;
  v_lock text;
BEGIN
  v_workspace := NEW.workspace_id;
  SELECT platform_company_id INTO v_company
  FROM public.erp_business_workspaces
  WHERE id = v_workspace;

  IF v_company IS NULL THEN
    RAISE EXCEPTION 'النشاط غير مرتبط بشركة سلسلة لتطبيق سياسات التكويد';
  END IF;

  IF nullif(NEW.local_code, '') IS NOT NULL THEN
    RETURN NEW;
  END IF;

  SELECT c.prefix, c.digits INTO v_prefix, v_digits
  FROM public.erp_code_policy_config(v_company, 'workspace_item_link', 'Wil', 5) c;

  v_lock := v_company::text || ':workspace_item_link:' || v_prefix;
  PERFORM pg_advisory_xact_lock(hashtextextended(v_lock, 0));

  SELECT coalesce(max(substring(t.local_code from '^' || v_prefix || '([0-9]+)$')::bigint), 0)
  INTO v_max
  FROM public.erp_business_workspace_item_links t
  JOIN public.erp_business_workspaces w ON w.id = t.workspace_id
  WHERE w.platform_company_id = v_company
    AND t.local_code ~ ('^' || v_prefix || '[0-9]+$');

  IF coalesce(v_max, 0) + 1 >= power(10::numeric, v_digits) THEN
    RAISE EXCEPTION 'انتهت خانات كود ربط الأصناف بالنشاط؛ زد عدد الخانات من سياسات التكويد';
  END IF;

  NEW.local_code := v_prefix || lpad((coalesce(v_max, 0) + 1)::text, v_digits, '0');
  RETURN NEW;
END;
$function$;

DROP TRIGGER IF EXISTS erp_business_workspace_item_links_central_code ON public.erp_business_workspace_item_links;
CREATE TRIGGER erp_business_workspace_item_links_central_code BEFORE INSERT ON public.erp_business_workspace_item_links
FOR EACH ROW EXECUTE FUNCTION public.erp_assign_workspace_item_link_code();

CREATE UNIQUE INDEX IF NOT EXISTS erp_hr_employee_contracts_company_contract_number_uidx
ON public.erp_hr_employee_contracts (company_id, contract_number)
WHERE contract_number IS NOT NULL AND contract_number <> '';

CREATE UNIQUE INDEX IF NOT EXISTS erp_hr_employee_advances_company_advance_number_uidx
ON public.erp_hr_employee_advances (company_id, advance_number)
WHERE advance_number IS NOT NULL AND advance_number <> '';

CREATE UNIQUE INDEX IF NOT EXISTS erp_business_workspace_item_links_workspace_local_code_uidx
ON public.erp_business_workspace_item_links (workspace_id, local_code)
WHERE local_code IS NOT NULL AND local_code <> '';

-- Allow the item prefix and serial length to be changed until the first item is
-- created. Category segments remain two digits each to preserve the existing
-- six-digit inherited category path.
CREATE OR REPLACE FUNCTION public.erp_assign_item_hierarchical_code()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO ''
AS $function$
DECLARE
  v_policy jsonb := '{}'::jsonb;
  v_segments jsonb := '{}'::jsonb;
  v_prefix text := 'Itm';
  v_main_digits integer := 2;
  v_sub_digits integer := 2;
  v_secondary_digits integer := 2;
  v_serial_digits integer := 3;
  v_path text[] := array[]::text[];
  v_node record;
  v_parent uuid;
  v_rank integer;
  v_max_rank numeric;
  v_serial integer;
  v_serial_max numeric;
  v_lock text;
  i integer;
BEGIN
  IF nullif(NEW.item_code, '') IS NOT NULL THEN
    RETURN NEW;
  END IF;
  IF NEW.category_id IS NULL THEN
    RAISE EXCEPTION 'اختر الفئة الثانوية قبل حفظ الصنف لتوليد كوده';
  END IF;

  SELECT CASE WHEN left(policy_value, 1) = '{' THEN policy_value::jsonb ELSE '{}'::jsonb END
    INTO v_policy
  FROM public.erp_program_policies
  WHERE company_id = NEW.company_id AND policy_key = 'code_generation_registry'
  LIMIT 1;

  v_prefix := coalesce(nullif(v_policy->>'item_prefix', ''), 'Itm');
  v_segments := coalesce(v_policy->'item_segments', '{}'::jsonb);
  v_main_digits := coalesce(nullif(v_segments->>'main', '')::integer, 2);
  v_sub_digits := coalesce(nullif(v_segments->>'sub', '')::integer, 2);
  v_secondary_digits := coalesce(nullif(v_segments->>'secondary', '')::integer, 2);
  v_serial_digits := coalesce(nullif(v_segments->>'serial', '')::integer, 3);

  IF v_prefix !~ '^[A-Za-z]{3}$' THEN
    RAISE EXCEPTION 'بادئة كود الأصناف يجب أن تكون ثلاثة أحرف إنجليزية';
  END IF;
  IF v_main_digits <> 2 OR v_sub_digits <> 2 OR v_secondary_digits <> 2
     OR v_serial_digits < 1 OR v_serial_digits > 8 THEN
    RAISE EXCEPTION 'سياسة كود الصنف تتطلب ستة أرقام موروثة للفئات وتسلسلاً من 1 إلى 8 أرقام';
  END IF;

  IF EXISTS (
    SELECT 1
    FROM jsonb_each(coalesce(v_policy->'types', '{}'::jsonb)) configured
    WHERE lower(coalesce(configured.value->>'prefix', '')) = lower(v_prefix)
  ) THEN
    RAISE EXCEPTION 'بادئة الأصناف مستخدمة بالفعل في نوع تكويد آخر';
  END IF;

  v_parent := NEW.category_id;
  FOR i IN 1..3 LOOP
    SELECT id, parent_id, category_code, created_at INTO v_node
    FROM public.erp_item_categories
    WHERE id = v_parent AND company_id = NEW.company_id AND is_active = true;
    IF NOT FOUND THEN
      RAISE EXCEPTION 'الفئة المختارة غير موجودة أو غير نشطة';
    END IF;

    SELECT count(*) INTO v_rank
    FROM public.erp_item_categories c
    WHERE c.company_id = NEW.company_id
      AND c.parent_id IS NOT DISTINCT FROM v_node.parent_id
      AND (c.created_at, c.id) <= (v_node.created_at, v_node.id);

    v_max_rank := CASE i
      WHEN 1 THEN power(10::numeric, v_secondary_digits) - 1
      WHEN 2 THEN power(10::numeric, v_sub_digits) - 1
      ELSE power(10::numeric, v_main_digits) - 1
    END;
    IF v_rank < 1 OR v_rank > v_max_rank THEN
      RAISE EXCEPTION 'عدد الفئات في المستوى % تجاوز سعة الكود المحددة (% خانات)', 4-i,
        CASE i WHEN 1 THEN v_secondary_digits WHEN 2 THEN v_sub_digits ELSE v_main_digits END;
    END IF;

    v_path := array_prepend(
      lpad(v_rank::text, CASE i WHEN 1 THEN v_secondary_digits WHEN 2 THEN v_sub_digits ELSE v_main_digits END, '0'),
      v_path
    );
    v_parent := v_node.parent_id;
    IF i < 3 AND v_parent IS NULL THEN
      RAISE EXCEPTION 'يجب اختيار فئة ثانوية مرتبطة بفئة رئيسية وفرعية';
    END IF;
    IF i = 3 AND v_parent IS NOT NULL THEN
      RAISE EXCEPTION 'مستويات فئات الأصناف يجب ألا تتجاوز ثلاثة مستويات';
    END IF;
  END LOOP;

  v_lock := NEW.company_id::text || ':item:' || v_prefix || array_to_string(v_path, '');
  PERFORM pg_advisory_xact_lock(hashtextextended(v_lock, 0));

  v_serial_max := power(10::numeric, v_serial_digits) - 1;
  EXECUTE format(
    'SELECT coalesce(max(right(item_code, %s)::integer), 0) FROM public.erp_items WHERE company_id = $1 AND item_code ~ $2',
    v_serial_digits
  )
  INTO v_serial
  USING NEW.company_id,
    '^' || v_prefix || array_to_string(v_path, '') || '[0-9]{' || v_serial_digits || '}$';

  IF coalesce(v_serial, 0) >= v_serial_max THEN
    RAISE EXCEPTION 'تم الوصول إلى الحد الأقصى للتسلسل داخل هذه الفئات؛ زد عدد خانات التسلسل';
  END IF;

  NEW.item_code := v_prefix || array_to_string(v_path, '') ||
    lpad((coalesce(v_serial, 0) + 1)::text, v_serial_digits, '0');
  RETURN NEW;
END;
$function$;

-- Backfill the registry from the persisted policy rows so the actual database
-- generator follows the settings displayed in the policy screen.
DO $migration$
DECLARE
  r record;
  v_type_key text;
  v_config jsonb;
  v_registry jsonb;
  v_types jsonb;
BEGIN
  FOR r IN
    SELECT company_id, policy_key, policy_value
    FROM public.erp_program_policies
    WHERE policy_key IN (
      'code_policy.employee','code_policy.user','code_policy.supplier',
      'code_policy.representative','code_policy.branch','code_policy.department',
      'code_policy.work_location','code_policy.job','code_policy.grade',
      'code_policy.salary_element'
    )
  LOOP
    v_type_key := CASE r.policy_key
      WHEN 'code_policy.employee' THEN 'employee'
      WHEN 'code_policy.user' THEN 'user'
      WHEN 'code_policy.supplier' THEN 'supplier'
      WHEN 'code_policy.representative' THEN 'delegate'
      WHEN 'code_policy.branch' THEN 'branch'
      WHEN 'code_policy.department' THEN 'department'
      WHEN 'code_policy.work_location' THEN 'work_location'
      WHEN 'code_policy.job' THEN 'job'
      WHEN 'code_policy.grade' THEN 'grade'
      WHEN 'code_policy.salary_element' THEN 'salary_element'
    END;
    BEGIN
      v_config := r.policy_value::jsonb;
    EXCEPTION WHEN others THEN
      CONTINUE;
    END;
    IF coalesce(v_config->>'prefix','') = '' OR coalesce(v_config->>'digits','') = '' THEN
      CONTINUE;
    END IF;
    SELECT CASE WHEN left(policy_value,1)='{' THEN policy_value::jsonb ELSE '{}'::jsonb END
      INTO v_registry
    FROM public.erp_program_policies
    WHERE company_id=r.company_id AND policy_key='code_generation_registry'
    LIMIT 1;
    IF v_registry IS NULL THEN CONTINUE; END IF;
    v_types := coalesce(v_registry->'types','{}'::jsonb);
    v_types := jsonb_set(
      v_types, ARRAY[v_type_key],
      coalesce(v_types->v_type_key,'{}'::jsonb) ||
        jsonb_build_object('prefix',v_config->>'prefix','digits',(v_config->>'digits')::integer),
      true
    );
    v_registry := jsonb_set(v_registry,'{types}',v_types,true);
    UPDATE public.erp_program_policies
    SET policy_value=v_registry::text
    WHERE company_id=r.company_id AND policy_key='code_generation_registry';
  END LOOP;

  FOR r IN
    SELECT company_id, policy_value
    FROM public.erp_program_policies
    WHERE policy_key='customer_code'
  LOOP
    BEGIN
      v_config := r.policy_value::jsonb;
    EXCEPTION WHEN others THEN
      CONTINUE;
    END;
    SELECT CASE WHEN left(policy_value,1)='{' THEN policy_value::jsonb ELSE '{}'::jsonb END
      INTO v_registry
    FROM public.erp_program_policies
    WHERE company_id=r.company_id AND policy_key='code_generation_registry'
    LIMIT 1;
    IF v_registry IS NULL THEN CONTINUE; END IF;
    v_types := coalesce(v_registry->'types','{}'::jsonb);
    v_types := jsonb_set(
      v_types,'{customer}',
      coalesce(v_types->'customer','{}'::jsonb) ||
        jsonb_build_object('prefix',coalesce(v_config->>'prefix','Cus'),'digits',coalesce((v_config->>'serial_digits')::integer,2)),
      true
    );
    v_registry := jsonb_set(v_registry,'{types}',v_types,true);
    UPDATE public.erp_program_policies
    SET policy_value=v_registry::text
    WHERE company_id=r.company_id AND policy_key='code_generation_registry';
  END LOOP;

  FOR r IN
    SELECT company_id, policy_value
    FROM public.erp_program_policies
    WHERE policy_key='item_code'
  LOOP
    BEGIN
      v_config := r.policy_value::jsonb;
    EXCEPTION WHEN others THEN
      CONTINUE;
    END;
    SELECT CASE WHEN left(policy_value,1)='{' THEN policy_value::jsonb ELSE '{}'::jsonb END
      INTO v_registry
    FROM public.erp_program_policies
    WHERE company_id=r.company_id AND policy_key='code_generation_registry'
    LIMIT 1;
    IF v_registry IS NULL THEN CONTINUE; END IF;
    v_registry := jsonb_set(v_registry,'{item_prefix}',to_jsonb(coalesce(v_config->>'prefix','Itm')),true);
    v_registry := jsonb_set(v_registry,'{item_segments}',jsonb_build_object(
      'main',2,'sub',2,'secondary',2,'serial',coalesce((v_config->>'serial_digits')::integer,3)
    ),true);
    UPDATE public.erp_program_policies
    SET policy_value=v_registry::text
    WHERE company_id=r.company_id AND policy_key='code_generation_registry';
  END LOOP;
END;
$migration$;

-- One authenticated RPC gives the policy screen accurate per-type lock state
-- without issuing dozens of independent PostgREST queries.
CREATE OR REPLACE FUNCTION public.erp_code_policy_lock_status(p_company_id uuid)
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

CREATE OR REPLACE FUNCTION public.erp_preview_next_extended_central_code(p_company_id uuid, p_entity_key text)
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

-- Align persisted legacy policy values with the defaults the UI exposes.
DO $migration$
DECLARE
  r record;
  v_type_key text;
  v_config jsonb;
  v_registry jsonb;
  v_types jsonb;
BEGIN
  FOR r IN
    SELECT company_id, policy_key, policy_value
    FROM public.erp_program_policies
    WHERE policy_key IN (
      'code_policy.employee','code_policy.user','code_policy.supplier',
      'code_policy.representative','code_policy.branch','code_policy.department',
      'code_policy.work_location','code_policy.job','code_policy.grade',
      'code_policy.salary_element'
    )
  LOOP
    v_type_key := CASE r.policy_key
      WHEN 'code_policy.employee' THEN 'employee'
      WHEN 'code_policy.user' THEN 'user'
      WHEN 'code_policy.supplier' THEN 'supplier'
      WHEN 'code_policy.representative' THEN 'delegate'
      WHEN 'code_policy.branch' THEN 'branch'
      WHEN 'code_policy.department' THEN 'department'
      WHEN 'code_policy.work_location' THEN 'work_location'
      WHEN 'code_policy.job' THEN 'job'
      WHEN 'code_policy.grade' THEN 'grade'
      WHEN 'code_policy.salary_element' THEN 'salary_element'
    END;
    BEGIN
      v_config := r.policy_value::jsonb;
    EXCEPTION WHEN others THEN
      CONTINUE;
    END;
    IF coalesce(v_config->>'prefix','') = '' OR coalesce(v_config->>'digits','') = '' THEN
      CONTINUE;
    END IF;
    SELECT CASE WHEN left(policy_value,1)='{' THEN policy_value::jsonb ELSE '{}'::jsonb END
      INTO v_registry
    FROM public.erp_program_policies
    WHERE company_id=r.company_id AND policy_key='code_generation_registry'
    LIMIT 1;
    IF v_registry IS NULL THEN CONTINUE; END IF;
    v_types := coalesce(v_registry->'types','{}'::jsonb);
    v_types := jsonb_set(
      v_types, ARRAY[v_type_key],
      coalesce(v_types->v_type_key,'{}'::jsonb) ||
        jsonb_build_object('prefix',v_config->>'prefix','digits',(v_config->>'digits')::integer),
      true
    );
    v_registry := jsonb_set(v_registry,'{types}',v_types,true);
    UPDATE public.erp_program_policies
    SET policy_value=v_registry::text
    WHERE company_id=r.company_id AND policy_key='code_generation_registry';
  END LOOP;

  FOR r IN
    SELECT company_id, policy_value
    FROM public.erp_program_policies
    WHERE policy_key='customer_code'
  LOOP
    BEGIN
      v_config := r.policy_value::jsonb;
    EXCEPTION WHEN others THEN
      CONTINUE;
    END;
    SELECT CASE WHEN left(policy_value,1)='{' THEN policy_value::jsonb ELSE '{}'::jsonb END
      INTO v_registry
    FROM public.erp_program_policies
    WHERE company_id=r.company_id AND policy_key='code_generation_registry'
    LIMIT 1;
    IF v_registry IS NULL THEN CONTINUE; END IF;
    v_types := coalesce(v_registry->'types','{}'::jsonb);
    v_types := jsonb_set(
      v_types,'{customer}',
      coalesce(v_types->'customer','{}'::jsonb) ||
        jsonb_build_object('prefix',coalesce(v_config->>'prefix','Cus'),'digits',coalesce((v_config->>'serial_digits')::integer,2)),
      true
    );
    v_registry := jsonb_set(v_registry,'{types}',v_types,true);
    UPDATE public.erp_program_policies
    SET policy_value=v_registry::text
    WHERE company_id=r.company_id AND policy_key='code_generation_registry';
  END LOOP;

  FOR r IN
    SELECT company_id, policy_value
    FROM public.erp_program_policies
    WHERE policy_key='item_code'
  LOOP
    BEGIN
      v_config := r.policy_value::jsonb;
    EXCEPTION WHEN others THEN
      CONTINUE;
    END;
    SELECT CASE WHEN left(policy_value,1)='{' THEN policy_value::jsonb ELSE '{}'::jsonb END
      INTO v_registry
    FROM public.erp_program_policies
    WHERE company_id=r.company_id AND policy_key='code_generation_registry'
    LIMIT 1;
    IF v_registry IS NULL THEN CONTINUE; END IF;
    v_registry := jsonb_set(v_registry,'{item_prefix}',to_jsonb(coalesce(v_config->>'prefix','Itm')),true);
    v_registry := jsonb_set(v_registry,'{item_segments}',jsonb_build_object(
      'main',2,'sub',2,'secondary',2,'serial',coalesce((v_config->>'serial_digits')::integer,3)
    ),true);
    UPDATE public.erp_program_policies
    SET policy_value=v_registry::text
    WHERE company_id=r.company_id AND policy_key='code_generation_registry';
  END LOOP;
END;
$migration$;
