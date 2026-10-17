-- Transactional order creation. Prices and product ownership are read from the database,
-- never trusted from values supplied by the mobile client.
BEGIN;

CREATE OR REPLACE FUNCTION public.place_supplier_order(
  p_supplier_id UUID,
  p_items JSONB,
  p_payment_method TEXT,
  p_delivery_address TEXT,
  p_notes TEXT DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_customer_id UUID := auth.uid();
  v_order_id BIGINT;
  v_total NUMERIC(12,2) := 0;
  v_item JSONB;
  v_product_id BIGINT;
  v_quantity NUMERIC(12,3);
  v_price NUMERIC(12,2);
  v_name TEXT;
  v_unit TEXT;
  v_available BOOLEAN;
  v_order JSONB;
BEGIN
  IF v_customer_id IS NULL THEN
    RAISE EXCEPTION 'يجب تسجيل الدخول قبل إنشاء الطلب';
  END IF;

  IF p_supplier_id IS NULL THEN
    RAISE EXCEPTION 'يجب تحديد المورد';
  END IF;

  IF p_delivery_address IS NULL OR btrim(p_delivery_address) = '' THEN
    RAISE EXCEPTION 'يجب تحديد عنوان التوصيل';
  END IF;

  IF p_payment_method NOT IN ('cash','supplier_credit','wallet','bank_transfer','account_balance') THEN
    RAISE EXCEPTION 'طريقة الدفع غير مدعومة';
  END IF;

  IF p_items IS NULL OR jsonb_typeof(p_items) <> 'array' OR jsonb_array_length(p_items) = 0 THEN
    RAISE EXCEPTION 'السلة فارغة';
  END IF;

  FOR v_item IN SELECT value FROM jsonb_array_elements(p_items)
  LOOP
    v_product_id := (v_item->>'product_id')::BIGINT;
    v_quantity := (v_item->>'quantity')::NUMERIC;

    IF v_product_id IS NULL OR v_quantity IS NULL OR v_quantity <= 0 THEN
      RAISE EXCEPTION 'بيانات المنتج أو الكمية غير صحيحة';
    END IF;

    SELECT price, name, unit, is_available
      INTO v_price, v_name, v_unit, v_available
      FROM public.products
     WHERE id = v_product_id
       AND supplier_id = p_supplier_id
     FOR SHARE;

    IF NOT FOUND OR NOT COALESCE(v_available, FALSE) THEN
      RAISE EXCEPTION 'يوجد منتج غير متاح أو لا يتبع المورد المحدد';
    END IF;

    v_total := v_total + (v_price * v_quantity);
  END LOOP;

  INSERT INTO public.orders (
    customer_id, supplier_id, total_amount, subtotal, status,
    payment_method, payment_status, delivery_address, notes
  ) VALUES (
    v_customer_id, p_supplier_id, v_total, v_total, 'pending',
    p_payment_method, 'pending', btrim(p_delivery_address), NULLIF(btrim(COALESCE(p_notes,'')), '')
  )
  RETURNING id INTO v_order_id;

  FOR v_item IN SELECT value FROM jsonb_array_elements(p_items)
  LOOP
    v_product_id := (v_item->>'product_id')::BIGINT;
    v_quantity := (v_item->>'quantity')::NUMERIC;

    SELECT price, name, unit
      INTO v_price, v_name, v_unit
      FROM public.products
     WHERE id = v_product_id
       AND supplier_id = p_supplier_id;

    INSERT INTO public.order_items (
      order_id, product_id, product_name, unit, quantity,
      unit_price, line_total, total_price
    ) VALUES (
      v_order_id, v_product_id, v_name, COALESCE(v_unit,'وحدة'), v_quantity,
      v_price, v_price * v_quantity, v_price * v_quantity
    );
  END LOOP;

  SELECT to_jsonb(o) INTO v_order FROM public.orders o WHERE o.id = v_order_id;
  RETURN v_order;
END;
$$;

REVOKE ALL ON FUNCTION public.place_supplier_order(UUID, JSONB, TEXT, TEXT, TEXT) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.place_supplier_order(UUID, JSONB, TEXT, TEXT, TEXT) TO authenticated;

COMMIT;
