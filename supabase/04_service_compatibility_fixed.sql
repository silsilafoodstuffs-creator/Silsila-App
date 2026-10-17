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
AS $$
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
$$;

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

CREATE OR REPLACE FUNCTION public.silsila_sync_supplier_details_compatibility()
RETURNS TRIGGER
LANGUAGE plpgsql
SET search_path = public
AS $$
BEGIN
  NEW.profile_id := COALESCE(NEW.profile_id, NEW.supplier_id);
  NEW.supplier_id := COALESCE(NEW.supplier_id, NEW.profile_id);
  NEW.description := COALESCE(NEW.business_description, NEW.description);
  NEW.business_description := COALESCE(NEW.business_description, NEW.description);
  NEW.minimum_invoice := COALESCE(NEW.minimum_order_amount, NEW.minimum_invoice);
  NEW.minimum_order_amount := COALESCE(NEW.minimum_order_amount, NEW.minimum_invoice);
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS silsila_supplier_details_compatibility ON public.supplier_details;
CREATE TRIGGER silsila_supplier_details_compatibility
BEFORE INSERT OR UPDATE ON public.supplier_details
FOR EACH ROW EXECUTE FUNCTION public.silsila_sync_supplier_details_compatibility();

ALTER TABLE public.offers
  ADD COLUMN IF NOT EXISTS activity_type TEXT,
  ADD COLUMN IF NOT EXISTS discount_percentage NUMERIC(5,2);

ALTER TABLE public.stories
  ADD COLUMN IF NOT EXISTS activity_type TEXT;

ALTER TABLE public.profiles
  ADD COLUMN IF NOT EXISTS role TEXT,
  ADD COLUMN IF NOT EXISTS points_balance INTEGER NOT NULL DEFAULT 0;

ALTER TABLE public.support_tickets
  ADD COLUMN IF NOT EXISTS category TEXT NOT NULL DEFAULT 'general',
  ADD COLUMN IF NOT EXISTS order_id BIGINT REFERENCES public.orders(id) ON DELETE SET NULL;

CREATE TABLE IF NOT EXISTS public.shipping_companies (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  profile_id UUID REFERENCES public.profiles(id) ON DELETE SET NULL,
  name TEXT NOT NULL,
  phone TEXT,
  is_active BOOLEAN NOT NULL DEFAULT TRUE,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS public.deliveries (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  order_id BIGINT NOT NULL REFERENCES public.orders(id) ON DELETE CASCADE,
  shipping_company_id UUID NOT NULL REFERENCES public.shipping_companies(id) ON DELETE RESTRICT,
  requested_by UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  pickup_address TEXT NOT NULL,
  delivery_address TEXT NOT NULL,
  notes TEXT,
  status TEXT NOT NULL DEFAULT 'pending',
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

UPDATE public.profiles p
SET points_balance = COALESCE((
  SELECT SUM(t.points)::INTEGER
  FROM public.loyalty_transactions t
  WHERE t.user_id = p.id
), 0);

CREATE OR REPLACE FUNCTION public.silsila_sync_loyalty_balance()
RETURNS TRIGGER
LANGUAGE plpgsql
SET search_path = public
AS $$
BEGIN
  IF TG_OP = 'INSERT' THEN
    UPDATE public.profiles
       SET points_balance = points_balance + NEW.points
     WHERE id = NEW.user_id;
    RETURN NEW;
  ELSIF TG_OP = 'DELETE' THEN
    UPDATE public.profiles
       SET points_balance = points_balance - OLD.points
     WHERE id = OLD.user_id;
    RETURN OLD;
  ELSIF TG_OP = 'UPDATE' THEN
    UPDATE public.profiles
       SET points_balance = points_balance - OLD.points + NEW.points
     WHERE id = NEW.user_id;
    RETURN NEW;
  END IF;
  RETURN NULL;
END;
$$;

DROP TRIGGER IF EXISTS silsila_loyalty_balance_sync ON public.loyalty_transactions;
CREATE TRIGGER silsila_loyalty_balance_sync
AFTER INSERT OR UPDATE OR DELETE ON public.loyalty_transactions
FOR EACH ROW EXECUTE FUNCTION public.silsila_sync_loyalty_balance();

CREATE TABLE IF NOT EXISTS public.user_goals (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  title TEXT NOT NULL,
  current_value NUMERIC(12,2) NOT NULL DEFAULT 0,
  target_value NUMERIC(12,2) NOT NULL DEFAULT 1,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

ALTER TABLE public.deliveries ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.shipping_companies ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.user_goals ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "shipping_companies_read_active" ON public.shipping_companies;
CREATE POLICY "shipping_companies_read_active" ON public.shipping_companies
FOR SELECT TO anon, authenticated USING (is_active = TRUE);

DROP POLICY IF EXISTS "deliveries_manage_own" ON public.deliveries;
DROP POLICY IF EXISTS "deliveries_read_participant" ON public.deliveries;
DROP POLICY IF EXISTS "deliveries_create_participant" ON public.deliveries;
CREATE POLICY "deliveries_read_participant" ON public.deliveries
FOR SELECT TO authenticated USING (
  requested_by = auth.uid()
  OR EXISTS (
    SELECT 1 FROM public.orders o
    WHERE o.id = deliveries.order_id
      AND (o.customer_id = auth.uid() OR o.supplier_id = auth.uid())
  )
);
CREATE POLICY "deliveries_create_participant" ON public.deliveries
FOR INSERT TO authenticated WITH CHECK (
  requested_by = auth.uid()
  AND EXISTS (
    SELECT 1 FROM public.orders o
    WHERE o.id = deliveries.order_id
      AND (o.customer_id = auth.uid() OR o.supplier_id = auth.uid())
  )
);

DROP POLICY IF EXISTS "user_goals_manage_own" ON public.user_goals;
CREATE POLICY "user_goals_manage_own" ON public.user_goals
FOR ALL TO authenticated USING (user_id = auth.uid()) WITH CHECK (user_id = auth.uid());

UPDATE public.profiles
SET role = CASE
  WHEN account_type IN ('مورد', 'supplier') THEN 'supplier'
  WHEN account_type IN ('مندوب', 'delegate') THEN 'delegate'
  WHEN account_type IN ('شركة شحن', 'shipping_company') THEN 'shipping_company'
  WHEN account_type IN ('إدارة نشاط', 'admin', 'management') THEN 'admin'
  ELSE 'customer'
END
WHERE role IS NULL OR btrim(role) = '';

CREATE OR REPLACE FUNCTION public.silsila_sync_profile_role()
RETURNS TRIGGER
LANGUAGE plpgsql
SET search_path = public
AS $$
BEGIN
  NEW.role := CASE
    WHEN NEW.account_type IN ('مورد', 'supplier') THEN 'supplier'
    WHEN NEW.account_type IN ('مندوب', 'delegate') THEN 'delegate'
    WHEN NEW.account_type IN ('شركة شحن', 'shipping_company') THEN 'shipping_company'
    WHEN NEW.account_type IN ('إدارة نشاط', 'admin', 'management') THEN 'admin'
    ELSE 'customer'
  END;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS silsila_profiles_role_compatibility ON public.profiles;
CREATE TRIGGER silsila_profiles_role_compatibility
BEFORE INSERT OR UPDATE OF account_type, role ON public.profiles
FOR EACH ROW EXECUTE FUNCTION public.silsila_sync_profile_role();

-- A limited public directory avoids exposing all profile columns just to discover suppliers.
CREATE OR REPLACE VIEW public.supplier_directory AS
SELECT id, full_name, activity_type, supplier_type, governorate, district,
       address, account_status
FROM public.profiles
WHERE role = 'supplier'
  AND account_status IN ('approved', 'active', 'مفعل', 'معتمد');

GRANT SELECT ON public.supplier_directory TO anon, authenticated;

COMMIT;
