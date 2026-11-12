-- Activity-scoped 15-position brand ticker for the Silsila app.
-- Brand logos live on the existing company-scoped brand master.
ALTER TABLE public.erp_brands
  ADD COLUMN IF NOT EXISTS logo_data bytea,
  ADD COLUMN IF NOT EXISTS logo_mime_type text;

ALTER TABLE public.erp_brands
  DROP CONSTRAINT IF EXISTS erp_brands_logo_mime_type_check;
ALTER TABLE public.erp_brands
  ADD CONSTRAINT erp_brands_logo_mime_type_check
  CHECK (logo_mime_type IS NULL OR logo_mime_type IN ('image/jpeg','image/png','image/webp','image/gif'));

CREATE TABLE IF NOT EXISTS public.erp_app_ticker_ads (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  company_id uuid NOT NULL,
  app_id uuid NOT NULL REFERENCES public.erp_managed_apps(id) ON DELETE CASCADE,
  activity_code text,
  slot_no integer NOT NULL CHECK (slot_no BETWEEN 1 AND 15),
  brand_id uuid NOT NULL,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT erp_app_ticker_ads_brand_company_fk
    FOREIGN KEY (company_id, brand_id)
    REFERENCES public.erp_brands(company_id, id) ON DELETE RESTRICT
);

CREATE UNIQUE INDEX IF NOT EXISTS erp_app_ticker_ads_scope_slot_uq
  ON public.erp_app_ticker_ads(app_id, COALESCE(activity_code, ''), slot_no);
CREATE INDEX IF NOT EXISTS erp_app_ticker_ads_brand_idx
  ON public.erp_app_ticker_ads(company_id, brand_id);

ALTER TABLE public.erp_app_ticker_ads ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS erp_app_ticker_ads_admin_select ON public.erp_app_ticker_ads;
CREATE POLICY erp_app_ticker_ads_admin_select
ON public.erp_app_ticker_ads FOR SELECT TO authenticated
USING (public.erp_user_has_company_role(company_id, ARRAY['owner','admin']::text[]));

DROP POLICY IF EXISTS erp_app_ticker_ads_admin_insert ON public.erp_app_ticker_ads;
CREATE POLICY erp_app_ticker_ads_admin_insert
ON public.erp_app_ticker_ads FOR INSERT TO authenticated
WITH CHECK (public.erp_user_has_company_role(company_id, ARRAY['owner','admin']::text[]));

DROP POLICY IF EXISTS erp_app_ticker_ads_admin_update ON public.erp_app_ticker_ads;
CREATE POLICY erp_app_ticker_ads_admin_update
ON public.erp_app_ticker_ads FOR UPDATE TO authenticated
USING (public.erp_user_has_company_role(company_id, ARRAY['owner','admin']::text[]))
WITH CHECK (public.erp_user_has_company_role(company_id, ARRAY['owner','admin']::text[]));

DROP POLICY IF EXISTS erp_app_ticker_ads_admin_delete ON public.erp_app_ticker_ads;
CREATE POLICY erp_app_ticker_ads_admin_delete
ON public.erp_app_ticker_ads FOR DELETE TO authenticated
USING (public.erp_user_has_company_role(company_id, ARRAY['owner','admin']::text[]));

REVOKE ALL ON public.erp_app_ticker_ads FROM anon, authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON public.erp_app_ticker_ads TO authenticated;

CREATE OR REPLACE FUNCTION public.erp_save_app_ticker_ads(
  p_app_id uuid,
  p_activity_code text,
  p_assignments jsonb
)
RETURNS integer
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $function$
DECLARE
  v_company_id uuid;
  v_activity_code text := NULLIF(btrim(p_activity_code), '');
  v_count integer;
BEGIN
  IF auth.uid() IS NULL THEN
    RAISE EXCEPTION 'Authentication required' USING ERRCODE = '42501';
  END IF;
  SELECT app.company_id INTO v_company_id
  FROM public.erp_managed_apps app
  WHERE app.id = p_app_id AND app.app_key = 'silsila';
  IF v_company_id IS NULL OR NOT public.erp_user_has_company_role(v_company_id, ARRAY['owner','admin']::text[]) THEN
    RAISE EXCEPTION 'Not authorized to manage this app ticker' USING ERRCODE = '42501';
  END IF;
  IF p_assignments IS NULL OR jsonb_typeof(p_assignments) <> 'array' THEN
    RAISE EXCEPTION 'Assignments must be a JSON array' USING ERRCODE = '22023';
  END IF;
  IF EXISTS (
    SELECT 1
    FROM jsonb_array_elements(p_assignments) AS item(value)
    GROUP BY (item.value->>'slot_no')::integer
    HAVING count(*) > 1
  ) THEN
    RAISE EXCEPTION 'A ticker position can contain only one brand' USING ERRCODE = '23505';
  END IF;
  IF EXISTS (
    SELECT 1
    FROM jsonb_array_elements(p_assignments) AS item(value)
    LEFT JOIN public.erp_brands b
      ON b.id = (item.value->>'brand_id')::uuid
     AND b.company_id = v_company_id
     AND b.is_active = true
    WHERE b.id IS NULL
       OR (item.value->>'slot_no') IS NULL
       OR (item.value->>'slot_no')::integer NOT BETWEEN 1 AND 15
  ) THEN
    RAISE EXCEPTION 'Invalid or inactive brand, or invalid ticker position' USING ERRCODE = '23503';
  END IF;

  DELETE FROM public.erp_app_ticker_ads
  WHERE app_id = p_app_id
    AND activity_code IS NOT DISTINCT FROM v_activity_code;

  INSERT INTO public.erp_app_ticker_ads(company_id, app_id, activity_code, slot_no, brand_id)
  SELECT v_company_id, p_app_id, v_activity_code,
         (item.value->>'slot_no')::integer,
         (item.value->>'brand_id')::uuid
  FROM jsonb_array_elements(p_assignments) AS item(value);

  GET DIAGNOSTICS v_count = ROW_COUNT;
  RETURN v_count;
END;
$function$;

REVOKE ALL ON FUNCTION public.erp_save_app_ticker_ads(uuid,text,jsonb) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.erp_save_app_ticker_ads(uuid,text,jsonb) TO authenticated;

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
    SELECT app.id, app.company_id
    FROM public.erp_managed_apps app
    WHERE app.app_key = 'silsila' AND app.status = 'active'
  ),
  specific_ranked AS (
    SELECT a.slot_no, a.brand_id, b.brand_code, b.brand_name,
           b.logo_data, b.logo_mime_type, a.activity_code,
           row_number() OVER (
             PARTITION BY a.slot_no
             ORDER BY a.updated_at DESC, a.created_at DESC
           ) AS slot_rank
    FROM public.erp_app_ticker_ads a
    JOIN app_scope s ON s.id = a.app_id AND s.company_id = a.company_id
    JOIN public.erp_brands b ON b.id = a.brand_id AND b.company_id = a.company_id
    WHERE NULLIF(btrim(p_activity_code), '') IS NOT NULL
      AND a.activity_code = NULLIF(btrim(p_activity_code), '')
      AND b.is_active = true
  ),
  global_ranked AS (
    SELECT a.slot_no, a.brand_id, b.brand_code, b.brand_name,
           b.logo_data, b.logo_mime_type, a.activity_code,
           row_number() OVER (
             PARTITION BY a.slot_no
             ORDER BY a.updated_at DESC, a.created_at DESC
           ) AS slot_rank
    FROM public.erp_app_ticker_ads a
    JOIN app_scope s ON s.id = a.app_id AND s.company_id = a.company_id
    JOIN public.erp_brands b ON b.id = a.brand_id AND b.company_id = a.company_id
    WHERE a.activity_code IS NULL AND b.is_active = true
  )
  SELECT chosen.slot_no, chosen.brand_id, chosen.brand_code, chosen.brand_name,
         chosen.logo_data, chosen.logo_mime_type, chosen.activity_code
  FROM (
    SELECT sp.slot_no, sp.brand_id, sp.brand_code, sp.brand_name,
           sp.logo_data, sp.logo_mime_type, sp.activity_code
    FROM specific_ranked sp
    WHERE sp.slot_rank = 1
    UNION ALL
    SELECT gp.slot_no, gp.brand_id, gp.brand_code, gp.brand_name,
           gp.logo_data, gp.logo_mime_type, gp.activity_code
    FROM global_ranked gp
    WHERE gp.slot_rank = 1
      AND NOT EXISTS (
        SELECT 1 FROM specific_ranked sp
        WHERE sp.slot_no = gp.slot_no AND sp.slot_rank = 1
      )
  ) chosen
  ORDER BY chosen.slot_no;
$function$;

REVOKE ALL ON FUNCTION public.get_silsila_public_ticker_ads(text) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.get_silsila_public_ticker_ads(text) TO anon, authenticated;
