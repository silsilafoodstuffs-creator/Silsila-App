-- Restrict direct profile visibility to the owning authenticated user.
-- Public marketplace access remains available through narrowly-scoped views only.
BEGIN;

DROP POLICY IF EXISTS public_approved_marketplace_directory ON public.profiles;

CREATE OR REPLACE VIEW public.supplier_directory AS
SELECT id, full_name, activity_type, supplier_type, governorate, district, account_status
FROM public.profiles
WHERE role = 'supplier'
  AND account_status IN ('approved', 'active', 'مفعل', 'معتمد');

CREATE OR REPLACE VIEW public.customer_directory AS
SELECT id, full_name, activity_type, customer_type, governorate, district, account_status
FROM public.profiles
WHERE role = 'customer'
  AND account_status IN ('approved', 'active', 'مفعل', 'معتمد');

CREATE OR REPLACE VIEW public.supplier_public_details AS
SELECT
  sd.supplier_id,
  sd.business_name,
  sd.description,
  sd.logo_url,
  sd.cover_url,
  sd.supplier_type,
  sd.activity_type,
  sd.pricing_policy,
  sd.minimum_invoice,
  sd.minimum_items,
  sd.accepts_negotiation,
  sd.is_verified,
  sd.rating,
  sd.created_at
FROM public.supplier_details sd
JOIN public.profiles p ON p.id = sd.supplier_id
WHERE sd.is_active = true
  AND p.role = 'supplier'
  AND p.account_status IN ('approved', 'active', 'مفعل', 'معتمد');

-- These views deliberately expose only marketplace-safe columns.
-- They run with the view owner's privileges; base-table RLS is not bypassed
-- for direct table access, and the predicates above are the public boundary.
ALTER VIEW public.supplier_directory SET (security_invoker = false);
ALTER VIEW public.customer_directory SET (security_invoker = false);
ALTER VIEW public.supplier_public_details SET (security_invoker = false);

GRANT SELECT ON public.supplier_directory TO anon, authenticated;
GRANT SELECT ON public.customer_directory TO anon, authenticated;
GRANT SELECT ON public.supplier_public_details TO anon, authenticated;

COMMIT;
