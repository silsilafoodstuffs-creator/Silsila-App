-- Require an active shipping company when a participant creates a delivery request.
BEGIN;

DROP POLICY IF EXISTS "deliveries_create_participant" ON public.deliveries;
CREATE POLICY "deliveries_create_participant" ON public.deliveries
FOR INSERT TO authenticated
WITH CHECK (
  requested_by = auth.uid()
  AND EXISTS (
    SELECT 1
    FROM public.orders o
    WHERE o.id = deliveries.order_id
      AND (o.customer_id = auth.uid() OR o.supplier_id = auth.uid())
  )
  AND EXISTS (
    SELECT 1
    FROM public.shipping_companies sc
    WHERE sc.id = deliveries.shipping_company_id
      AND sc.is_active = TRUE
  )
);

COMMIT;
