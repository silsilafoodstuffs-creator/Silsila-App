-- Harden public supplier/customer directories without removing the intended public listing.
-- The views execute with caller permissions, and their base tables enforce row-level security.

GRANT SELECT (id, full_name, role, account_status, activity_type, customer_type, supplier_type, governorate, district)
ON public.profiles TO anon, authenticated;

GRANT SELECT (supplier_id, business_name, description, logo_url, cover_url, supplier_type, activity_type, pricing_policy, minimum_invoice, minimum_items, accepts_negotiation, is_verified, rating, created_at, is_active)
ON public.supplier_details TO anon, authenticated;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies
    WHERE schemaname='public' AND tablename='profiles'
      AND policyname='public_approved_marketplace_directory'
  ) THEN
    CREATE POLICY public_approved_marketplace_directory ON public.profiles
      FOR SELECT TO anon, authenticated
      USING (
        (role = 'supplier' AND account_status IN ('approved','active','مفعل','معتمد'))
        OR
        (role = 'customer' AND account_status IN ('approved','active','مفعل','معتمد'))
      );
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM pg_policies
    WHERE schemaname='public' AND tablename='supplier_details'
      AND policyname='public_approved_supplier_details'
  ) THEN
    CREATE POLICY public_approved_supplier_details ON public.supplier_details
      FOR SELECT TO anon
      USING (
        is_active = true AND EXISTS (
          SELECT 1 FROM public.profiles p
          WHERE p.id = supplier_details.supplier_id
            AND p.role = 'supplier'
            AND p.account_status IN ('approved','active','مفعل','معتمد')
        )
      );
  END IF;
END $$;

ALTER VIEW public.supplier_directory SET (security_invoker = true);
ALTER VIEW public.supplier_public_details SET (security_invoker = true);
ALTER VIEW public.customer_directory SET (security_invoker = true);
