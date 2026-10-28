BEGIN;

-- Activity-scoped category tree with binary images stored directly in PostgreSQL.
ALTER TABLE public.erp_item_categories
  ADD COLUMN IF NOT EXISTS activity_code text,
  ADD COLUMN IF NOT EXISTS parent_id uuid REFERENCES public.erp_item_categories(id) ON DELETE RESTRICT,
  ADD COLUMN IF NOT EXISTS category_name_en text NOT NULL DEFAULT '',
  ADD COLUMN IF NOT EXISTS is_active boolean NOT NULL DEFAULT true,
  ADD COLUMN IF NOT EXISTS show_in_app boolean NOT NULL DEFAULT true,
  ADD COLUMN IF NOT EXISTS image_url text,
  ADD COLUMN IF NOT EXISTS image_data bytea,
  ADD COLUMN IF NOT EXISTS image_mime_type text;

CREATE INDEX IF NOT EXISTS erp_item_categories_company_activity_code_idx
  ON public.erp_item_categories(company_id, activity_code, category_code);
CREATE INDEX IF NOT EXISTS erp_item_categories_company_activity_parent_idx
  ON public.erp_item_categories(company_id, activity_code, parent_id);
CREATE UNIQUE INDEX IF NOT EXISTS erp_item_categories_company_activity_code_uq
  ON public.erp_item_categories(company_id, activity_code, category_code)
  WHERE activity_code IS NOT NULL;

-- Generate familiar alphanumeric codes automatically and keep the hierarchy within three levels.
CREATE OR REPLACE FUNCTION public.erp_item_categories_validate_tree_and_code()
RETURNS trigger
LANGUAGE plpgsql
SET search_path = public
AS $$
DECLARE
  parent_company uuid;
  parent_activity text;
  parent_parent_id uuid;
  parent_grandparent_id uuid;
  next_number bigint;
BEGIN
  IF NEW.category_code IS NULL OR btrim(NEW.category_code) = '' THEN
    SELECT COALESCE(MAX(NULLIF(regexp_replace(category_code, '[^0-9]', '', 'g'), '')::bigint), 0) + 1
      INTO next_number
      FROM public.erp_item_categories
      WHERE company_id = NEW.company_id
        AND activity_code IS NOT DISTINCT FROM NEW.activity_code;
    NEW.category_code := 'CAT' || lpad(next_number::text, 5, '0');
  ELSIF (TG_OP = 'INSERT' OR NEW.category_code IS DISTINCT FROM OLD.category_code)
        AND NEW.category_code !~ '^[A-Za-z]+[A-Za-z0-9]*$' THEN
    RAISE EXCEPTION 'كود الفئة يجب أن يتكون من حروف إنجليزية وأرقام فقط.';
  END IF;

  IF NEW.parent_id IS NOT NULL THEN
    SELECT p.company_id, p.activity_code, p.parent_id, gp.parent_id
      INTO parent_company, parent_activity, parent_parent_id, parent_grandparent_id
      FROM public.erp_item_categories p
      LEFT JOIN public.erp_item_categories gp ON gp.id = p.parent_id
      WHERE p.id = NEW.parent_id;

    IF NOT FOUND THEN
      -- Allows a parent inserted earlier in the same save sequence only; a missing parent is invalid.
      RAISE EXCEPTION 'الفئة الرئيسية المحددة غير موجودة.';
    END IF;
    IF parent_company IS DISTINCT FROM NEW.company_id
       OR parent_activity IS DISTINCT FROM NEW.activity_code THEN
      RAISE EXCEPTION 'يجب أن تنتمي الفئة وأصلها إلى الشركة والنشاط نفسيهما.';
    END IF;
    IF parent_parent_id IS NOT NULL AND parent_grandparent_id IS NOT NULL THEN
      RAISE EXCEPTION 'يسمح بثلاثة مستويات فقط: رئيسية وفرعية وثانوية.';
    END IF;
    IF NEW.parent_id = NEW.id THEN
      RAISE EXCEPTION 'لا يمكن أن تكون الفئة أصلًا لنفسها.';
    END IF;
  END IF;

  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS erp_item_categories_validate_tree_and_code
  ON public.erp_item_categories;
CREATE TRIGGER erp_item_categories_validate_tree_and_code
BEFORE INSERT OR UPDATE OF category_code, company_id, activity_code, parent_id
ON public.erp_item_categories
FOR EACH ROW
EXECUTE FUNCTION public.erp_item_categories_validate_tree_and_code();

COMMIT;
