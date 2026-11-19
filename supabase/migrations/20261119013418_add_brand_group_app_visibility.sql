ALTER TABLE public.erp_brand_groups
  ADD COLUMN IF NOT EXISTS show_in_app boolean NOT NULL DEFAULT true;

COMMENT ON COLUMN public.erp_brand_groups.show_in_app IS
  'Controls whether the brand group is displayed in the Silsila app.';
