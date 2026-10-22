-- Shared live catalogue: ERP master records are the source of truth for app-visible catalog data.
ALTER TABLE public.activity_types ADD COLUMN IF NOT EXISTS code text;
UPDATE public.activity_types
SET code = 'ACT' || lpad(greatest(sort_order, 1)::text, 3, '0')
WHERE code IS NULL OR btrim(code) = '';
CREATE UNIQUE INDEX IF NOT EXISTS activity_types_code_uidx
  ON public.activity_types (code) WHERE code IS NOT NULL;

ALTER TABLE public.erp_items
  ADD COLUMN IF NOT EXISTS show_in_app boolean NOT NULL DEFAULT true;

-- App clients may read only active catalog records explicitly exposed to the app.
DROP POLICY IF EXISTS erp_item_groups_public_catalog_read ON public.erp_item_groups;
CREATE POLICY erp_item_groups_public_catalog_read
  ON public.erp_item_groups FOR SELECT TO anon, authenticated
  USING (is_active = true AND show_in_app = true);

DROP POLICY IF EXISTS erp_items_public_catalog_read ON public.erp_items;
CREATE POLICY erp_items_public_catalog_read
  ON public.erp_items FOR SELECT TO anon, authenticated
  USING (
    is_active = true
    AND show_in_app = true
    AND EXISTS (
      SELECT 1
      FROM public.erp_item_groups g
      WHERE g.id = erp_items.group_id
        AND g.company_id = erp_items.company_id
        AND g.is_active = true
        AND g.show_in_app = true
    )
  );

-- Login buttons are controlled by the ERP's user-type grid.
DROP POLICY IF EXISTS erp_user_types_public_login_read ON public.erp_user_types;
CREATE POLICY erp_user_types_public_login_read
  ON public.erp_user_types FOR SELECT TO anon, authenticated
  USING (is_active = true AND show_at_login = true);

GRANT SELECT ON public.activity_types, public.erp_item_groups, public.erp_items, public.erp_user_types TO anon, authenticated;
