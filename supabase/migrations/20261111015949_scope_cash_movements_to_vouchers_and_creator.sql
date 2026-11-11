-- Cash movements inherit the scope of their posted voucher. Standalone
-- unvouchered movements are visible only to their creator and company admins.
DROP POLICY IF EXISTS erp_scope_guard_erp_cash_movements ON public.erp_cash_movements;
CREATE POLICY erp_scope_guard_erp_cash_movements
ON public.erp_cash_movements AS RESTRICTIVE FOR ALL TO authenticated
USING (
  public.erp_user_has_company_role(company_id, ARRAY['owner','admin']::text[])
  OR (created_by = auth.uid() AND cash_voucher_id IS NULL)
  OR EXISTS (
    SELECT 1
    FROM public.erp_cash_vouchers v
    WHERE v.id=erp_cash_movements.cash_voucher_id
      AND v.company_id=erp_cash_movements.company_id
      AND (
        (v.branch_id IS NOT NULL AND public.erp_user_can_access_branch_scope(v.company_id,v.branch_id))
        OR EXISTS (
          SELECT 1 FROM public.erp_cashboxes cb
          WHERE cb.company_id=v.company_id
            AND cb.id IN (v.source_cashbox_id,v.destination_cashbox_id)
            AND cb.branch_id IS NOT NULL
            AND public.erp_user_can_access_branch_scope(cb.company_id,cb.branch_id)
        )
      )
  )
)
WITH CHECK (
  public.erp_user_has_company_role(company_id, ARRAY['owner','admin']::text[])
  OR (created_by = auth.uid() AND cash_voucher_id IS NULL)
  OR EXISTS (
    SELECT 1
    FROM public.erp_cash_vouchers v
    WHERE v.id=erp_cash_movements.cash_voucher_id
      AND v.company_id=erp_cash_movements.company_id
      AND (
        (v.branch_id IS NOT NULL AND public.erp_user_can_access_branch_scope(v.company_id,v.branch_id))
        OR EXISTS (
          SELECT 1 FROM public.erp_cashboxes cb
          WHERE cb.company_id=v.company_id
            AND cb.id IN (v.source_cashbox_id,v.destination_cashbox_id)
            AND cb.branch_id IS NOT NULL
            AND public.erp_user_can_access_branch_scope(cb.company_id,cb.branch_id)
        )
      )
  )
);
