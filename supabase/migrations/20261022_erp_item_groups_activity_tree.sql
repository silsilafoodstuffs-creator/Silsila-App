-- Scope the ERP item-category tree to a registered business activity.
ALTER TABLE public.erp_item_groups
  ADD COLUMN IF NOT EXISTS activity_code text NOT NULL DEFAULT 'ACT001';

CREATE INDEX IF NOT EXISTS erp_item_groups_company_activity_parent_idx
  ON public.erp_item_groups (company_id, activity_code, parent_id, group_code);

CREATE OR REPLACE FUNCTION public.erp_prevent_duplicate_item_group_names()
RETURNS trigger
LANGUAGE plpgsql
SET search_path = public
AS $$
BEGIN
  IF nullif(btrim(coalesce(NEW.group_name, '')), '') IS NOT NULL
     AND EXISTS (
       SELECT 1
       FROM public.erp_item_groups AS existing
       WHERE existing.company_id = NEW.company_id
         AND existing.activity_code = NEW.activity_code
         AND lower(btrim(existing.group_name)) = lower(btrim(NEW.group_name))
         AND existing.id IS DISTINCT FROM NEW.id
     ) THEN
    RAISE EXCEPTION 'اسم الفئة مستخدم بالفعل داخل هذا النشاط: %', NEW.group_name
      USING ERRCODE = '23505';
  END IF;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS erp_item_groups_no_duplicate_names ON public.erp_item_groups;
CREATE TRIGGER erp_item_groups_no_duplicate_names
BEFORE INSERT OR UPDATE OF company_id, activity_code, group_name
ON public.erp_item_groups
FOR EACH ROW
EXECUTE FUNCTION public.erp_prevent_duplicate_item_group_names();
