
CREATE OR REPLACE FUNCTION public.erp_import_whatsapp_contacts_atomic(
  p_company_id uuid,
  p_source_label text,
  p_source_file_name text,
  p_source_type text,
  p_contacts jsonb
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY INVOKER
SET search_path = ''
AS $function$
DECLARE
  v_user_id uuid := auth.uid();
  v_batch_id uuid;
  v_requested integer;
  v_inserted integer := 0;
BEGIN
  IF v_user_id IS NULL THEN
    RAISE EXCEPTION 'يجب تسجيل الدخول قبل استيراد جهات الاتصال' USING ERRCODE = '28000';
  END IF;
  IF p_company_id IS NULL OR NOT public.erp_user_can_access_company(p_company_id) THEN
    RAISE EXCEPTION 'لا تملك صلاحية استيراد جهات الاتصال إلى هذه الشركة' USING ERRCODE = '42501';
  END IF;
  IF p_source_type IS NULL OR p_source_type <> ALL (ARRAY['csv','vcard','manual','official_api']::text[]) THEN
    RAISE EXCEPTION 'مصدر ملف الاستيراد غير معتمد' USING ERRCODE = '22023';
  END IF;
  IF p_contacts IS NULL OR jsonb_typeof(p_contacts) <> 'array' THEN
    RAISE EXCEPTION 'قائمة جهات الاتصال غير صالحة' USING ERRCODE = '22023';
  END IF;
  v_requested := jsonb_array_length(p_contacts);
  IF v_requested < 1 OR v_requested > 5000 THEN
    RAISE EXCEPTION 'يجب أن يحتوي الاستيراد على 1 إلى 5000 جهة اتصال في الدفعة الواحدة' USING ERRCODE = '22023';
  END IF;
  IF EXISTS (
    SELECT 1 FROM jsonb_array_elements(p_contacts) AS e(value)
    WHERE jsonb_typeof(e.value) <> 'object'
       OR EXISTS (
         SELECT 1 FROM jsonb_object_keys(e.value) AS k(key)
         WHERE k.key <> ALL (ARRAY['name','phone','normalized_phone','group','source']::text[])
       )
       OR NULLIF(BTRIM(e.value->>'phone'),'') IS NULL
       OR NULLIF(BTRIM(e.value->>'normalized_phone'),'') IS NULL
       OR length(regexp_replace(translate(e.value->>'normalized_phone',
            '٠١٢٣٤٥٦٧٨٩۰۱۲۳۴۵۶۷۸۹','01234567890123456789'),'[^0-9]','','g')) < 7
       OR regexp_replace(translate(e.value->>'phone',
            '٠١٢٣٤٥٦٧٨٩۰۱۲۳۴۵۶۷۸۹','01234567890123456789'),'[^0-9]','','g')
          <> regexp_replace(translate(e.value->>'normalized_phone',
            '٠١٢٣٤٥٦٧٨٩۰۱۲۳۴۵۶۷۸۹','01234567890123456789'),'[^0-9]','','g')
       OR COALESCE(NULLIF(e.value->>'source',''),'uploaded_file')
          <> ALL (ARRAY['uploaded_file','csv','vcard','official_api','manual']::text[])
  ) THEN
    RAISE EXCEPTION 'تحتوي قائمة جهات الاتصال على رقم أو مصدر أو خصائص غير صالحة' USING ERRCODE = '22023';
  END IF;
  IF EXISTS (
    SELECT 1 FROM jsonb_array_elements(p_contacts) AS e(value)
    GROUP BY e.value->>'normalized_phone' HAVING count(*) > 1
  ) THEN
    RAISE EXCEPTION 'قائمة الاستيراد تحتوي على رقم مكرر بعد التطبيع' USING ERRCODE = '23505';
  END IF;
  INSERT INTO public.erp_whatsapp_import_batches(
    company_id,source_label,source_file_name,source_type,total_contacts,created_by
  )
  VALUES(
    p_company_id,COALESCE(NULLIF(BTRIM(p_source_label),''),'استيراد ملف'),
    COALESCE(NULLIF(BTRIM(p_source_file_name),''),''),p_source_type,v_requested,v_user_id
  )
  RETURNING id INTO v_batch_id;
  INSERT INTO public.erp_whatsapp_import_contacts(
    company_id,batch_id,contact_name,phone,normalized_phone,group_name,
    source_type,consent_status,created_by
  )
  SELECT p_company_id,v_batch_id,COALESCE(BTRIM(x.name),''),
    BTRIM(x.phone),BTRIM(x.normalized_phone),COALESCE(BTRIM(x.group_name),''),
    COALESCE(NULLIF(x.source_type,''),'uploaded_file'),'pending',v_user_id
  FROM jsonb_to_recordset(p_contacts) AS x(
    name text,phone text,normalized_phone text,group_name text,source_type text
  );
  GET DIAGNOSTICS v_inserted = ROW_COUNT;
  IF v_inserted <> v_requested THEN
    RAISE EXCEPTION 'عدد جهات الاتصال المحفوظة لا يطابق عدد السجلات في الدفعة' USING ERRCODE = '23514';
  END IF;
  RETURN jsonb_build_object('batch_id',v_batch_id,'requested_count',v_requested,
    'inserted_count',v_inserted,'consent_status','pending');
END;
$function$;
REVOKE ALL ON FUNCTION public.erp_import_whatsapp_contacts_atomic(uuid,text,text,text,jsonb) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.erp_import_whatsapp_contacts_atomic(uuid,text,text,text,jsonb) FROM anon;
GRANT EXECUTE ON FUNCTION public.erp_import_whatsapp_contacts_atomic(uuid,text,text,text,jsonb) TO authenticated;
