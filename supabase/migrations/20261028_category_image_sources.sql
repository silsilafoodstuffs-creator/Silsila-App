-- Store source and attribution metadata for imported category photographs.
ALTER TABLE public.erp_item_categories
  ADD COLUMN IF NOT EXISTS image_source_url text,
  ADD COLUMN IF NOT EXISTS image_attribution text;
COMMENT ON COLUMN public.erp_item_categories.image_source_url IS 'Source page for the real category image, when imported from Wikimedia Commons.';
COMMENT ON COLUMN public.erp_item_categories.image_attribution IS 'Image creator and license attribution for reuse compliance.';
