-- Remove the redundant attendance index and support cashbox FK lookups.
-- The two attendance indexes had identical definitions:
-- (company_id, work_date). Keep erp_attendance_company_date_idx.
DROP INDEX IF EXISTS public.erp_attendance_company_day_idx;

-- Support FK checks and joins on payment-method cashbox references.
CREATE INDEX IF NOT EXISTS erp_payment_methods_cashbox_id_idx
  ON public.erp_payment_methods USING btree (cashbox_id);
