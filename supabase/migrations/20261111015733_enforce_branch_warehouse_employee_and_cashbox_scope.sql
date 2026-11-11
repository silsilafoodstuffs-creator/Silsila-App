-- Enforce branch, warehouse and employee assignment boundaries on ERP rows.
-- Owner/admin remain able to administer company-wide data; other users must have
-- an explicit branch/warehouse assignment. Employee-linked HR rows inherit the
-- employee's assigned branch. Payment methods inherit their assigned cashbox.

CREATE OR REPLACE FUNCTION public.erp_user_can_access_employee_scope(
  p_company_id uuid, p_employee_id uuid
) RETURNS boolean
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = ''
AS $$
DECLARE v_branch_id uuid;
BEGIN
  IF auth.uid() IS NULL OR p_company_id IS NULL OR p_employee_id IS NULL THEN RETURN false; END IF;
  IF public.erp_user_has_company_role(p_company_id, ARRAY['owner','admin']::text[]) THEN RETURN true; END IF;
  SELECT e.branch_id INTO v_branch_id
  FROM public.erp_employees e
  WHERE e.id = p_employee_id AND e.company_id = p_company_id;
  IF NOT FOUND OR v_branch_id IS NULL THEN RETURN false; END IF;
  RETURN public.erp_user_can_access_branch_scope(p_company_id, v_branch_id);
END;
$$;
REVOKE ALL ON FUNCTION public.erp_user_can_access_employee_scope(uuid,uuid) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.erp_user_can_access_employee_scope(uuid,uuid) TO authenticated;

DO $$
DECLARE r record; v_predicate text;
BEGIN
  FOR r IN
    SELECT c.table_name,
      bool_or(c.column_name='branch_id') AS has_branch,
      bool_or(c.column_name='warehouse_id') AS has_warehouse,
      bool_or(c.column_name='employee_id') AS has_employee
    FROM information_schema.columns c
    JOIN pg_class pc ON pc.relname=c.table_name
    JOIN pg_namespace pn ON pn.oid=pc.relnamespace AND pn.nspname='public'
    WHERE c.table_schema='public' AND c.table_name LIKE 'erp_%'
      AND pc.relkind IN ('r','p')
      AND c.column_name IN ('company_id','branch_id','warehouse_id','employee_id')
    GROUP BY c.table_name
    HAVING bool_or(c.column_name='company_id')
       AND (bool_or(c.column_name='branch_id') OR bool_or(c.column_name='warehouse_id') OR bool_or(c.column_name='employee_id'))
  LOOP
    v_predicate := '';
    IF r.has_branch THEN
      v_predicate := 'branch_id IS NOT NULL AND public.erp_user_can_access_branch_scope(company_id, branch_id)';
    END IF;
    IF r.has_warehouse THEN
      IF v_predicate <> '' THEN v_predicate := v_predicate || ' AND '; END IF;
      v_predicate := v_predicate || 'warehouse_id IS NOT NULL AND public.erp_user_can_access_warehouse_scope(company_id, ' ||
        CASE WHEN r.has_branch THEN 'COALESCE(branch_id, (SELECT w.branch_id FROM public.erp_warehouses w WHERE w.id = warehouse_id))'
             ELSE '(SELECT w.branch_id FROM public.erp_warehouses w WHERE w.id = warehouse_id)' END ||
        ', warehouse_id)';
    END IF;
    IF r.has_employee THEN
      IF v_predicate <> '' THEN v_predicate := v_predicate || ' AND '; END IF;
      v_predicate := v_predicate || 'employee_id IS NOT NULL AND public.erp_user_can_access_employee_scope(company_id, employee_id)';
    END IF;
    EXECUTE format('DROP POLICY IF EXISTS %I ON public.%I', 'erp_scope_guard_'||r.table_name, r.table_name);
    EXECUTE format('CREATE POLICY %I ON public.%I AS RESTRICTIVE FOR ALL TO authenticated USING (%s) WITH CHECK (%s)',
      'erp_scope_guard_'||r.table_name, r.table_name, v_predicate, v_predicate);
  END LOOP;
END;
$$;

DROP POLICY IF EXISTS erp_scope_guard_erp_payment_methods ON public.erp_payment_methods;
CREATE POLICY erp_scope_guard_erp_payment_methods
ON public.erp_payment_methods AS RESTRICTIVE FOR ALL TO authenticated
USING (cashbox_id IS NOT NULL AND EXISTS (
  SELECT 1 FROM public.erp_cashboxes cb
  WHERE cb.id=erp_payment_methods.cashbox_id AND cb.company_id=erp_payment_methods.company_id
    AND cb.branch_id IS NOT NULL AND public.erp_user_can_access_branch_scope(cb.company_id,cb.branch_id)
))
WITH CHECK (cashbox_id IS NOT NULL AND EXISTS (
  SELECT 1 FROM public.erp_cashboxes cb
  WHERE cb.id=erp_payment_methods.cashbox_id AND cb.company_id=erp_payment_methods.company_id
    AND cb.branch_id IS NOT NULL AND public.erp_user_can_access_branch_scope(cb.company_id,cb.branch_id)
));
