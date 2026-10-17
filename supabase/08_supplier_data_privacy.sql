-- Keep private supplier registration documents out of public queries.
BEGIN;

DROP VIEW IF EXISTS public.supplier_directory;
CREATE VIEW public.supplier_directory AS
SELECT id, full_name, activity_type, supplier_type, governorate, district, account_status
FROM public.profiles
WHERE role = 'supplier'
  AND account_status IN ('approved', 'active', 'مفعل', 'معتمد');

GRANT SELECT ON public.supplier_directory TO anon, authenticated;

DROP POLICY IF EXISTS "supplier_details_read" ON public.supplier_details;
DROP POLICY IF EXISTS "supplier_details_manage_own" ON public.supplier_details;
CREATE POLICY "supplier_details_manage_own" ON public.supplier_details
FOR ALL TO authenticated
USING (profile_id = auth.uid())
WITH CHECK (profile_id = auth.uid());

CREATE OR REPLACE VIEW public.supplier_public_details AS
SELECT
  supplier_id,
  business_name,
  description,
  logo_url,
  cover_url,
  supplier_type,
  activity_type,
  pricing_policy,
  minimum_invoice,
  minimum_items,
  accepts_negotiation,
  is_verified,
  rating,
  created_at
FROM public.supplier_details;

GRANT SELECT ON public.supplier_public_details TO anon, authenticated;

COMMIT;
