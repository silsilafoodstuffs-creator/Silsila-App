-- Compatibility columns required by current Silsila Dart services.
-- Apply after 01_core_schema.sql and before enabling live supplier/product workflows.
BEGIN;

ALTER TABLE public.products
  ADD COLUMN IF NOT EXISTS category TEXT,
  ADD COLUMN IF NOT EXISTS min_quantity NUMERIC(12,3) NOT NULL DEFAULT 1,
  ADD COLUMN IF NOT EXISTS is_active BOOLEAN NOT NULL DEFAULT TRUE,
  ADD COLUMN IF NOT EXISTS image_url TEXT;

UPDATE public.products
SET category = COALESCE(category, (SELECT name FROM public.categories WHERE id = products.category_id)),
    min_quantity = COALESCE(min_quantity, minimum_quantity, 1),
    is_active = COALESCE(is_active, is_available, TRUE);

ALTER TABLE public.supplier_details
  ADD COLUMN IF NOT EXISTS supplier_id UUID,
  ADD COLUMN IF NOT EXISTS business_description TEXT,
  ADD COLUMN IF NOT EXISTS commercial_registration TEXT,
  ADD COLUMN IF NOT EXISTS tax_number TEXT,
  ADD COLUMN IF NOT EXISTS minimum_order_amount NUMERIC(12,2),
  ADD COLUMN IF NOT EXISTS accepts_negotiation BOOLEAN NOT NULL DEFAULT TRUE;

UPDATE public.supplier_details
SET supplier_id = COALESCE(supplier_id, profile_id),
    business_description = COALESCE(business_description, description),
    minimum_order_amount = COALESCE(minimum_order_amount, minimum_invoice);

CREATE UNIQUE INDEX IF NOT EXISTS idx_supplier_details_supplier_id
  ON public.supplier_details(supplier_id);

ALTER TABLE public.offers
  ADD COLUMN IF NOT EXISTS activity_type TEXT,
  ADD COLUMN IF NOT EXISTS discount_percentage NUMERIC(5,2);

ALTER TABLE public.stories
  ADD COLUMN IF NOT EXISTS activity_type TEXT;

ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS role TEXT;

UPDATE public.profiles
SET role = CASE
  WHEN account_type IN ('مورد', 'supplier') THEN 'supplier'
  WHEN account_type IN ('مندوب', 'delegate') THEN 'delegate'
  WHEN account_type IN ('شركة شحن', 'shipping_company') THEN 'shipping_company'
  WHEN account_type IN ('إدارة نشاط', 'admin', 'management') THEN 'admin'
  ELSE 'customer'
END
WHERE role IS NULL OR btrim(role) = '';

COMMIT;
