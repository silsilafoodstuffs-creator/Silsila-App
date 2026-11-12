-- Expand Silsila's activity-scoped logo ticker from 15 to 25 positions.
ALTER TABLE public.erp_app_ticker_ads
  DROP CONSTRAINT IF EXISTS erp_app_ticker_ads_slot_no_check;
ALTER TABLE public.erp_app_ticker_ads
  ADD CONSTRAINT erp_app_ticker_ads_slot_no_check
  CHECK (slot_no BETWEEN 1 AND 25);

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
       OR (item.value->>'slot_no')::integer NOT BETWEEN 1 AND 25
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
