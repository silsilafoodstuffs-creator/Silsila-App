-- Extend atomic brand renames to include the activity code edited in the detail dialog.
CREATE OR REPLACE FUNCTION public.erp_update_brand_names_batch(
  p_company_id uuid,
  p_rows jsonb
)
RETURNS integer
LANGUAGE plpgsql
SECURITY INVOKER
SET search_path = ''
AS $function$
DECLARE
  v_requested integer;
  v_updated integer;
  v_marker text := '__silsila_tmp_' || gen_random_uuid()::text || '_';
BEGIN
  IF p_company_id IS NULL OR jsonb_typeof(p_rows) IS DISTINCT FROM 'array' THEN
    RAISE EXCEPTION 'بيانات تعديل البراندات غير صالحة' USING ERRCODE = '22023';
  END IF;
  SELECT count(*) INTO v_requested FROM jsonb_array_elements(p_rows);
  IF v_requested = 0 THEN RETURN 0; END IF;
  IF EXISTS (
    SELECT 1 FROM jsonb_to_recordset(p_rows) AS x(id uuid, brand_name text, brand_name_en text, activity_code text)
    WHERE x.id IS NULL OR nullif(btrim(x.brand_name), '') IS NULL
  ) THEN RAISE EXCEPTION 'اسم البراند العربي مطلوب' USING ERRCODE = '22023'; END IF;
  IF EXISTS (
    SELECT 1 FROM jsonb_to_recordset(p_rows) AS x(id uuid, brand_name text, brand_name_en text, activity_code text)
    GROUP BY x.id HAVING count(*) > 1
  ) THEN RAISE EXCEPTION 'تم إرسال البراند نفسه أكثر من مرة' USING ERRCODE = '22023'; END IF;
  IF EXISTS (
    SELECT 1 FROM jsonb_to_recordset(p_rows) AS x(id uuid, brand_name text, brand_name_en text, activity_code text)
    GROUP BY lower(btrim(x.brand_name)) HAVING count(*) > 1
  ) THEN RAISE EXCEPTION 'أسماء البراندات العربية المقترحة مكررة' USING ERRCODE = '23505'; END IF;
  IF EXISTS (
    SELECT 1
    FROM public.erp_brands b
    JOIN jsonb_to_recordset(p_rows) AS x(id uuid, brand_name text, brand_name_en text, activity_code text)
      ON lower(btrim(b.brand_name)) = lower(btrim(x.brand_name))
    WHERE b.company_id = p_company_id
      AND NOT EXISTS (
        SELECT 1 FROM jsonb_to_recordset(p_rows) AS target(id uuid, brand_name text, brand_name_en text, activity_code text)
        WHERE target.id = b.id
      )
  ) THEN RAISE EXCEPTION 'اسم البراند العربي مستخدم بالفعل في سجل آخر' USING ERRCODE = '23505'; END IF;
  IF (
    SELECT count(*)
    FROM public.erp_brands b
    JOIN jsonb_to_recordset(p_rows) AS x(id uuid, brand_name text, brand_name_en text, activity_code text)
      ON x.id = b.id
    WHERE b.company_id = p_company_id AND coalesce(b.is_system, false) = false
  ) <> v_requested THEN
    RAISE EXCEPTION 'تعذر الوصول إلى أحد سجلات البراند المحددة أو أنه سجل محمي' USING ERRCODE = 'P0002';
  END IF;
  UPDATE public.erp_brands b
  SET brand_name = v_marker || b.id::text
  FROM jsonb_to_recordset(p_rows) AS x(id uuid, brand_name text, brand_name_en text, activity_code text)
  WHERE b.id = x.id AND b.company_id = p_company_id;
  UPDATE public.erp_brands b
  SET brand_name = btrim(x.brand_name),
      brand_name_en = nullif(btrim(coalesce(x.brand_name_en, '')), ''),
      activity_code = coalesce(nullif(btrim(coalesce(x.activity_code, '')), ''), b.activity_code)
  FROM jsonb_to_recordset(p_rows) AS x(id uuid, brand_name text, brand_name_en text, activity_code text)
  WHERE b.id = x.id AND b.company_id = p_company_id;
  GET DIAGNOSTICS v_updated = ROW_COUNT;
  IF v_updated <> v_requested THEN
    RAISE EXCEPTION 'لم يتم تحديث جميع سجلات البراند المطلوبة' USING ERRCODE = 'P0002';
  END IF;
  RETURN v_updated;
END;
$function$;
REVOKE ALL ON FUNCTION public.erp_update_brand_names_batch(uuid, jsonb) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.erp_update_brand_names_batch(uuid, jsonb) TO authenticated;
