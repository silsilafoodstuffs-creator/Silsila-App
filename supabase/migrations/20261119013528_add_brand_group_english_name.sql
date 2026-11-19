ALTER TABLE public.erp_brand_groups
  ADD COLUMN IF NOT EXISTS group_name_en text;

COMMENT ON COLUMN public.erp_brand_groups.group_name_en IS
  'Optional English display name for a brand group.';
