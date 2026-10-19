ALTER TABLE public.products
  ADD COLUMN IF NOT EXISTS subcategory TEXT,
  ADD COLUMN IF NOT EXISTS brand TEXT,
  ADD COLUMN IF NOT EXISTS package_count INTEGER NOT NULL DEFAULT 1 CHECK (package_count > 0),
  ADD COLUMN IF NOT EXISTS small_unit TEXT,
  ADD COLUMN IF NOT EXISTS offer_price NUMERIC(12,2) CHECK (offer_price IS NULL OR offer_price >= 0);

CREATE INDEX IF NOT EXISTS products_activity_category_subcategory_idx
  ON public.products (activity_type, category, subcategory);
CREATE INDEX IF NOT EXISTS products_brand_idx ON public.products (brand);
