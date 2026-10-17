-- Restrict the public supplier details view to approved accounts.
BEGIN;
CREATE OR REPLACE VIEW public.supplier_public_details AS
SELECT sd.supplier_id, sd.business_name, sd.description, sd.logo_url, sd.cover_url,
       sd.supplier_type, sd.activity_type, sd.pricing_policy, sd.minimum_invoice,
       sd.minimum_items, sd.accepts_negotiation, sd.is_verified, sd.rating, sd.created_at
FROM public.supplier_details AS sd
INNER JOIN public.profiles AS p ON p.id = sd.supplier_id
WHERE p.role = 'supplier'
  AND p.account_status IN ('approved', 'active', 'مفعل', 'معتمد');
GRANT SELECT ON public.supplier_public_details TO anon, authenticated;
COMMIT;
