-- Administrative shipping-company management and assigned-delivery status updates.
BEGIN;

CREATE UNIQUE INDEX IF NOT EXISTS idx_shipping_companies_profile_unique
  ON public.shipping_companies(profile_id)
  WHERE profile_id IS NOT NULL;

CREATE OR REPLACE FUNCTION public.admin_list_shipping_companies()
RETURNS TABLE (
  id UUID,
  profile_id UUID,
  name TEXT,
  phone TEXT,
  is_active BOOLEAN,
  created_at TIMESTAMPTZ
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF auth.uid() IS NULL OR NOT EXISTS (
    SELECT 1 FROM public.profiles p WHERE p.id = auth.uid() AND p.role = 'admin'
  ) THEN
    RAISE EXCEPTION 'هذه العملية متاحة لإدارة النشاط فقط';
  END IF;

  RETURN QUERY
  SELECT sc.id, sc.profile_id, sc.name, sc.phone, sc.is_active, sc.created_at
  FROM public.shipping_companies sc
  ORDER BY sc.name
  LIMIT 200;
END;
$$;

CREATE OR REPLACE FUNCTION public.admin_save_shipping_company(
  p_company_id UUID,
  p_profile_id UUID,
  p_name TEXT,
  p_phone TEXT,
  p_is_active BOOLEAN DEFAULT TRUE
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_id UUID;
BEGIN
  IF auth.uid() IS NULL OR NOT EXISTS (
    SELECT 1 FROM public.profiles p WHERE p.id = auth.uid() AND p.role = 'admin'
  ) THEN
    RAISE EXCEPTION 'هذه العملية متاحة لإدارة النشاط فقط';
  END IF;

  IF NULLIF(btrim(COALESCE(p_name,'')), '') IS NULL THEN
    RAISE EXCEPTION 'اسم شركة الشحن مطلوب';
  END IF;

  IF p_profile_id IS NOT NULL AND NOT EXISTS (
    SELECT 1 FROM public.profiles p
    WHERE p.id = p_profile_id AND p.role = 'shipping_company'
  ) THEN
    RAISE EXCEPTION 'يجب ربط شركة الشحن بحساب من نوع شركة شحن';
  END IF;

  IF p_company_id IS NOT NULL THEN
    UPDATE public.shipping_companies
       SET profile_id = p_profile_id,
           name = btrim(p_name),
           phone = NULLIF(btrim(COALESCE(p_phone,'')), ''),
           is_active = COALESCE(p_is_active, TRUE)
     WHERE id = p_company_id
     RETURNING id INTO v_id;
  END IF;

  IF v_id IS NULL AND p_profile_id IS NOT NULL THEN
    INSERT INTO public.shipping_companies(profile_id, name, phone, is_active)
    VALUES (p_profile_id, btrim(p_name), NULLIF(btrim(COALESCE(p_phone,'')), ''), COALESCE(p_is_active, TRUE))
    ON CONFLICT (profile_id) WHERE profile_id IS NOT NULL
    DO UPDATE SET name = EXCLUDED.name, phone = EXCLUDED.phone, is_active = EXCLUDED.is_active
    RETURNING id INTO v_id;
  END IF;

  IF v_id IS NULL THEN
    INSERT INTO public.shipping_companies(name, phone, is_active)
    VALUES (btrim(p_name), NULLIF(btrim(COALESCE(p_phone,'')), ''), COALESCE(p_is_active, TRUE))
    RETURNING id INTO v_id;
  END IF;

  RETURN (SELECT to_jsonb(sc) FROM public.shipping_companies sc WHERE sc.id = v_id);
END;
$$;

CREATE OR REPLACE FUNCTION public.shipping_company_update_delivery_status(
  p_delivery_id UUID,
  p_new_status TEXT,
  p_note TEXT DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_user_id UUID := auth.uid();
  v_role TEXT;
  v_current_status TEXT;
  v_order_id BIGINT;
  v_order_status TEXT;
  v_result JSONB;
BEGIN
  IF v_user_id IS NULL THEN
    RAISE EXCEPTION 'يجب تسجيل الدخول أولاً';
  END IF;

  SELECT role INTO v_role FROM public.profiles WHERE id = v_user_id;
  IF COALESCE(v_role, '') <> 'admin' AND NOT EXISTS (
    SELECT 1 FROM public.shipping_companies sc
    JOIN public.deliveries d ON d.shipping_company_id = sc.id
    WHERE d.id = p_delivery_id AND sc.profile_id = v_user_id
  ) THEN
    RAISE EXCEPTION 'لا تملك صلاحية تحديث هذه الشحنة';
  END IF;

  SELECT status, order_id INTO v_current_status, v_order_id
    FROM public.deliveries
   WHERE id = p_delivery_id
   FOR UPDATE;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'الشحنة غير موجودة';
  END IF;

  IF v_current_status IN ('تم التسليم','ملغي','مُلغي') THEN
    RAISE EXCEPTION 'هذه الشحنة مغلقة بالفعل';
  END IF;

  IF p_new_status NOT IN ('قيد الاستلام','في الطريق','تم التسليم','ملغي','مُلغي') THEN
    RAISE EXCEPTION 'حالة الشحنة غير مدعومة';
  END IF;

  UPDATE public.deliveries
     SET status = p_new_status, updated_at = NOW()
   WHERE id = p_delivery_id
   RETURNING to_jsonb(deliveries.*) INTO v_result;

  IF p_new_status = 'تم التسليم' THEN
    SELECT status INTO v_order_status FROM public.orders WHERE id = v_order_id FOR UPDATE;
    IF v_order_status = 'توصيل' THEN
      UPDATE public.orders SET status = 'تم التسليم', updated_at = NOW() WHERE id = v_order_id;
      INSERT INTO public.order_status_history(order_id, status, changed_by, note)
      VALUES (v_order_id, 'تم التسليم', v_user_id, NULLIF(btrim(COALESCE(p_note,'')), ''));
    END IF;
  END IF;

  RETURN v_result;
END;
$$;

DROP POLICY IF EXISTS "deliveries_read_participant" ON public.deliveries;
CREATE POLICY "deliveries_read_participant" ON public.deliveries
FOR SELECT TO authenticated USING (
  requested_by = auth.uid()
  OR EXISTS (
    SELECT 1 FROM public.orders o
    WHERE o.id = deliveries.order_id
      AND (o.customer_id = auth.uid() OR o.supplier_id = auth.uid())
  )
  OR EXISTS (
    SELECT 1 FROM public.shipping_companies sc
    WHERE sc.id = deliveries.shipping_company_id AND sc.profile_id = auth.uid()
  )
);

REVOKE ALL ON FUNCTION public.admin_list_shipping_companies() FROM PUBLIC;
REVOKE ALL ON FUNCTION public.admin_save_shipping_company(UUID, UUID, TEXT, TEXT, BOOLEAN) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.shipping_company_update_delivery_status(UUID, TEXT, TEXT) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.admin_list_shipping_companies() TO authenticated;
GRANT EXECUTE ON FUNCTION public.admin_save_shipping_company(UUID, UUID, TEXT, TEXT, BOOLEAN) TO authenticated;
GRANT EXECUTE ON FUNCTION public.shipping_company_update_delivery_status(UUID, TEXT, TEXT) TO authenticated;

COMMIT;
