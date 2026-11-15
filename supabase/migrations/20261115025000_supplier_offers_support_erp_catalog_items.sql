-- Let supplier offers reference company-owned ERP master items.
-- Keep the legacy products FK for already-listed public supplier products.
ALTER TABLE public.offer_items
  ADD COLUMN IF NOT EXISTS erp_item_id uuid
  REFERENCES public.erp_items(id) ON DELETE SET NULL;

CREATE INDEX IF NOT EXISTS offer_items_erp_item_id_idx
  ON public.offer_items(erp_item_id)
  WHERE erp_item_id IS NOT NULL;

ALTER TABLE public.offer_items
  DROP CONSTRAINT IF EXISTS offer_items_product_source_exclusive;
ALTER TABLE public.offer_items
  ADD CONSTRAINT offer_items_product_source_exclusive
  CHECK (product_id IS NULL OR erp_item_id IS NULL);

CREATE OR REPLACE FUNCTION public.validate_supplier_offer_erp_item()
RETURNS trigger
LANGUAGE plpgsql
SECURITY INVOKER
SET search_path = ''
AS $function$
DECLARE
  v_supplier_id uuid;
BEGIN
  IF NEW.erp_item_id IS NULL THEN
    RETURN NEW;
  END IF;

  SELECT o.supplier_id INTO v_supplier_id
  FROM public.offers o
  WHERE o.id = NEW.offer_id;

  IF v_supplier_id IS NULL OR NOT EXISTS (
    SELECT 1
    FROM public.erp_items i
    WHERE i.id = NEW.erp_item_id
      AND i.is_active = true
      AND (
        EXISTS (
          SELECT 1 FROM public.erp_company_members m
          WHERE m.user_id = v_supplier_id
            AND m.company_id = i.company_id
            AND m.is_active = true
        )
        OR EXISTS (
          SELECT 1 FROM public.erp_users u
          WHERE u.auth_user_id = v_supplier_id
            AND u.company_id = i.company_id
            AND u.is_active = true
        )
      )
  ) THEN
    RAISE EXCEPTION 'صنف العرض لا يتبع شركة المورد أو أنه غير نشط'
      USING ERRCODE = '23503';
  END IF;

  RETURN NEW;
END;
$function$;

REVOKE ALL ON FUNCTION public.validate_supplier_offer_erp_item() FROM PUBLIC, anon, authenticated;
DROP TRIGGER IF EXISTS offer_items_validate_supplier_erp_item ON public.offer_items;
CREATE TRIGGER offer_items_validate_supplier_erp_item
BEFORE INSERT OR UPDATE OF offer_id, erp_item_id
ON public.offer_items
FOR EACH ROW
EXECUTE FUNCTION public.validate_supplier_offer_erp_item();
