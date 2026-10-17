-- Compatibility columns required by current Silsila Dart services.
-- Apply after 01_core_schema.sql and before enabling live supplier/product workflows.
BEGIN;

ALTER TABLE public.categories ADD COLUMN IF NOT EXISTS icon TEXT;

ALTER TABLE public.products
  ADD COLUMN IF NOT EXISTS category TEXT,
  ADD COLUMN IF NOT EXISTS min_quantity NUMERIC(12,3) NOT NULL DEFAULT 1,
  ADD COLUMN IF NOT EXISTS is_active BOOLEAN NOT NULL DEFAULT TRUE,
  ADD COLUMN IF NOT EXISTS image_url TEXT;

UPDATE public.products p
SET category = COALESCE(NULLIF(p.category, ''), (SELECT name FROM public.categories WHERE id = p.category_id)),
    min_quantity = COALESCE(p.minimum_quantity, p.min_quantity, 1),
    is_active = COALESCE(p.is_available, p.is_active, TRUE);

CREATE OR REPLACE FUNCTION public.silsila_sync_product_compatibility()
RETURNS TRIGGER
LANGUAGE plpgsql
SET search_path = public
AS $
BEGIN
  IF TG_OP = 'INSERT' THEN
    NEW.minimum_quantity := COALESCE(NEW.minimum_quantity, NEW.min_quantity, 1);
    NEW.min_quantity := COALESCE(NEW.min_quantity, NEW.minimum_quantity, 1);
    NEW.is_available := COALESCE(NEW.is_available, NEW.is_active, TRUE);
    NEW.is_active := COALESCE(NEW.is_active, NEW.is_available, TRUE);
  ELSE
    IF NEW.min_quantity IS DISTINCT FROM OLD.min_quantity
       AND NEW.minimum_quantity IS NOT DISTINCT FROM OLD.minimum_quantity THEN
      NEW.minimum_quantity := NEW.min_quantity;
    ELSIF NEW.minimum_quantity IS DISTINCT FROM OLD.minimum_quantity
       AND NEW.min_quantity IS NOT DISTINCT FROM OLD.min_quantity THEN
      NEW.min_quantity := NEW.minimum_quantity;
    END IF;
    IF NEW.is_active IS DISTINCT FROM OLD.is_active
       AND NEW.is_available IS NOT DISTINCT FROM OLD.is_available THEN
      NEW.is_available := NEW.is_active;
    ELSIF NEW.is_available IS DISTINCT FROM OLD.is_available
       AND NEW.is_active IS NOT DISTINCT FROM OLD.is_active THEN
      NEW.is_active := NEW.is_available;
    END IF;
  END IF;
  IF NEW.category_id IS NULL AND NEW.category IS NOT NULL THEN
    SELECT id INTO NEW.category_id FROM public.categories
    WHERE name = NEW.category ORDER BY sort_order, id LIMIT 1;
  END IF;
  IF (NEW.category IS NULL OR NEW.category = '') AND NEW.category_id IS NOT NULL THEN
    SELECT name INTO NEW.category FROM public.categories WHERE id = NEW.category_id;
  END IF;
  RETURN NEW;
END;
$;

DROP TRIGGER IF EXISTS silsila_products_compatibility ON public.products;
CREATE TRIGGER silsila_products_compatibility
BEFORE INSERT OR UPDATE ON public.products
FOR EACH ROW EXECUTE FUNCTION public.silsila_sync_product_compatibility();

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
