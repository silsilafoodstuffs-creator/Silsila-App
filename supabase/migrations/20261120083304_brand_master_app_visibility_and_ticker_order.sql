-- Make brand master the single source of truth for app visibility and ticker order.
ALTER TABLE public.erp_brands
  ADD COLUMN IF NOT EXISTS show_in_app boolean NOT NULL DEFAULT true;

UPDATE public.erp_brands SET show_in_app = true WHERE show_in_app IS NULL;

CREATE INDEX IF NOT EXISTS erp_brands_company_app_visibility_order_idx
  ON public.erp_brands(company_id, show_in_app, is_active, display_order, brand_code);

-- Ignore legacy manual ticker slots: the brand master controls visibility and order.
CREATE OR REPLACE FUNCTION public.get_silsila_public_ticker_ads(
  p_activity_code text DEFAULT NULL
)
RETURNS TABLE(
  slot_no integer,
  brand_id uuid,
  brand_code text,
  brand_name text,
  logo_data bytea,
  logo_mime_type text,
  activity_code text
)
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = ''
AS $function$
  WITH app_scope AS (
    SELECT app.company_id
    FROM public.erp_managed_apps app
    WHERE app.app_key = 'silsila' AND app.status = 'active'
  ),
  visible_brands AS (
    SELECT b.id, b.brand_code, b.brand_name, b.logo_data, b.logo_mime_type,
           b.activity_code, b.display_order
    FROM public.erp_brands b
    JOIN app_scope scope ON scope.company_id = b.company_id
    WHERE b.is_active = true
      AND b.is_system = false
      AND b.show_in_app = true
      AND (
        NULLIF(btrim(p_activity_code), '') IS NULL
        OR b.activity_code = NULLIF(btrim(p_activity_code), '')
      )
  )
  SELECT
    row_number() OVER (ORDER BY display_order NULLS LAST, brand_code, id)::integer AS slot_no,
    id AS brand_id,
    brand_code,
    brand_name,
    logo_data,
    logo_mime_type,
    activity_code
  FROM visible_brands
  ORDER BY display_order NULLS LAST, brand_code, id;
$function$;

REVOKE ALL ON FUNCTION public.get_silsila_public_ticker_ads(text) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.get_silsila_public_ticker_ads(text) TO anon, authenticated;
