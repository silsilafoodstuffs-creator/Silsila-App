-- Allow branchless rows only when their linked warehouse or employee
-- independently proves the user's assigned scope. Cash vouchers inherit scope
-- from either their explicit branch or their linked source/destination cashbox.

DO $$
DECLARE r record; v_predicate text; v_branch_expr text;
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
      v_branch_expr := 'branch_id IS NOT NULL AND public.erp_user_can_access_branch_scope(company_id, branch_id)';
      IF r.has_warehouse THEN
        v_branch_expr := v_branch_expr || ' OR (branch_id IS NULL AND warehouse_id IS NOT NULL AND public.erp_user_can_access_warehouse_scope(company_id, (SELECT w.branch_id FROM public.erp_warehouses w WHERE w.id=warehouse_id), warehouse_id))';
      END IF;
      IF r.has_employee THEN
        v_branch_expr := v_branch_expr || ' OR (branch_id IS NULL AND employee_id IS NOT NULL AND public.erp_user_can_access_employee_scope(company_id, employee_id))';
      END IF;
      v_predicate := '(' || v_branch_expr || ')';
    END IF;
    IF r.has_warehouse THEN
      IF v_predicate <> '' THEN v_predicate := v_predicate || ' AND '; END IF;
      v_predicate := v_predicate ||
        'warehouse_id IS NOT NULL AND public.erp_user_can_access_warehouse_scope(company_id, ' ||
        CASE WHEN r.has_branch THEN 'COALESCE(branch_id, (SELECT w.branch_id FROM public.erp_warehouses w WHERE w.id=warehouse_id))'
             ELSE '(SELECT w.branch_id FROM public.erp_warehouses w WHERE w.id=warehouse_id)' END ||
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

DROP POLICY IF EXISTS erp_scope_guard_erp_cash_vouchers ON public.erp_cash_vouchers;
CREATE POLICY erp_scope_guard_erp_cash_vouchers
ON public.erp_cash_vouchers AS RESTRICTIVE FOR ALL TO authenticated
USING (
  (branch_id IS NOT NULL AND public.erp_user_can_access_branch_scope(company_id,branch_id))
  OR EXISTS (
    SELECT 1 FROM public.erp_cashboxes cb
    WHERE cb.company_id=erp_cash_vouchers.company_id
      AND cb.id IN (erp_cash_vouchers.source_cashbox_id,erp_cash_vouchers.destination_cashbox_id)
      AND cb.branch_id IS NOT NULL
      AND public.erp_user_can_access_branch_scope(cb.company_id,cb.branch_id)
  )
)
WITH CHECK (
  (branch_id IS NOT NULL AND public.erp_user_can_access_branch_scope(company_id,branch_id))
  OR EXISTS (
    SELECT 1 FROM public.erp_cashboxes cb
    WHERE cb.company_id=erp_cash_vouchers.company_id
      AND cb.id IN (erp_cash_vouchers.source_cashbox_id,erp_cash_vouchers.destination_cashbox_id)
      AND cb.branch_id IS NOT NULL
      AND public.erp_user_can_access_branch_scope(cb.company_id,cb.branch_id)
  )
);
