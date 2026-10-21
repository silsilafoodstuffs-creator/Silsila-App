-- Store catalog and ERP images as PostgreSQL binary data (bytea), not external image URLs.
ALTER TABLE public.categories
  ADD COLUMN IF NOT EXISTS image_data bytea,
  ADD COLUMN IF NOT EXISTS image_mime_type text;
ALTER TABLE public.products
  ADD COLUMN IF NOT EXISTS image_data bytea,
  ADD COLUMN IF NOT EXISTS image_mime_type text;
ALTER TABLE public.erp_item_groups
  ADD COLUMN IF NOT EXISTS image_data bytea,
  ADD COLUMN IF NOT EXISTS image_mime_type text;
ALTER TABLE public.erp_items
  ADD COLUMN IF NOT EXISTS image_data bytea,
  ADD COLUMN IF NOT EXISTS image_mime_type text;

COMMENT ON COLUMN public.categories.image_data IS 'Binary image bytes stored in PostgreSQL.';
COMMENT ON COLUMN public.products.image_data IS 'Binary image bytes stored in PostgreSQL.';
COMMENT ON COLUMN public.erp_item_groups.image_data IS 'Binary image bytes stored in PostgreSQL.';
COMMENT ON COLUMN public.erp_items.image_data IS 'Binary image bytes stored in PostgreSQL.';
