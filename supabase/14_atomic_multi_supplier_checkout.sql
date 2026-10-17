-- Create every supplier sub-order in one transaction; wallet payments are debited once.
BEGIN;

CREATE OR REPLACE FUNCTION public.place_multi_supplier_checkout(
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
  v_item RECORD;
  v_product RECORD;
  v_supplier_id UUID;
  v_product_id BIGINT;
  v_quantity NUMERIC(12,3);
  v_supplier_total NUMERIC(12,2);
  v_total NUMERIC(12,2) := 0;
  v_order_id BIGINT;
  v_wallet_id UUID;
  v_balance NUMERIC(12,2);
  v_order_ids JSONB := '[]'::JSONB;
  v_orders JSONB := '[]'::JSONB;
  v_reference TEXT := 'checkout-' || gen_random_uuid()::TEXT;
  v_is_wallet_payment BOOLEAN := FALSE;
BEGIN
  IF v_customer_id IS NULL THEN
    RAISE EXCEPTION 'يجب تسجيل الدخول قبل إنشاء الطلب';
  END IF;

  IF p_delivery_address IS NULL OR btrim(p_delivery_address) = '' THEN
    RAISE EXCEPTION 'يجب تحديد عنوان التوصيل';
  END IF;

  IF p_payment_method NOT IN ('نقدي','آجل مورد','محفظة كاش','تحويل بنكي','من الرصيد') THEN
    RAISE EXCEPTION 'طريقة الدفع غير مدعومة';
  END IF;

  IF p_items IS NULL OR jsonb_typeof(p_items) <> 'array' OR jsonb_array_length(p_items) = 0 THEN
    RAISE EXCEPTION 'السلة فارغة';
  END IF;

  IF EXISTS (
    SELECT 1
    FROM jsonb_to_recordset(p_items) AS x(supplier_id UUID, product_id BIGINT, quantity NUMERIC)
    WHERE x.supplier_id IS NULL OR x.product_id IS NULL OR x.quantity IS NULL OR x.quantity <= 0
  ) THEN
    RAISE EXCEPTION 'بيانات المنتج أو الكمية غير صحيحة';
  END IF;

  -- Lock and validate each distinct product in a stable order; aggregate duplicate lines.
  FOR v_item IN
    SELECT x.supplier_id, x.product_id, SUM(x.quantity)::NUMERIC(12,3) AS quantity
    FROM jsonb_to_recordset(p_items) AS x(supplier_id UUID, product_id BIGINT, quantity NUMERIC)
    GROUP BY x.supplier_id, x.product_id
    ORDER BY x.product_id, x.supplier_id
  LOOP
    SELECT id, supplier_id, price, name, unit, is_available,
           minimum_quantity, stock_quantity, track_inventory
      INTO v_product
      FROM public.products
     WHERE id = v_item.product_id
       AND supplier_id = v_item.supplier_id
     FOR UPDATE;

    IF NOT FOUND OR NOT COALESCE(v_product.is_available, FALSE) THEN
      RAISE EXCEPTION 'يوجد منتج غير متاح أو لا يتبع المورد المحدد';
    END IF;

    IF v_item.quantity < COALESCE(v_product.minimum_quantity, 1) THEN
      RAISE EXCEPTION 'الكمية أقل من الحد الأدنى للمنتج %', v_product.name;
    END IF;

    IF COALESCE(v_product.track_inventory, FALSE)
       AND v_item.quantity > COALESCE(v_product.stock_quantity, 0) THEN
      RAISE EXCEPTION 'الكمية المطلوبة تتجاوز المخزون المتاح للمنتج %', v_product.name;
    END IF;

    v_total := v_total + (v_product.price * v_item.quantity);
  END LOOP;

  -- Create one order per supplier while preserving a single transaction for the full cart.
  FOR v_supplier_id IN
    SELECT DISTINCT x.supplier_id
    FROM jsonb_to_recordset(p_items) AS x(supplier_id UUID, product_id BIGINT, quantity NUMERIC)
    ORDER BY x.supplier_id
  LOOP
    v_supplier_total := 0;

    FOR v_item IN
      SELECT x.product_id, SUM(x.quantity)::NUMERIC(12,3) AS quantity
      FROM jsonb_to_recordset(p_items) AS x(supplier_id UUID, product_id BIGINT, quantity NUMERIC)
      WHERE x.supplier_id = v_supplier_id
      GROUP BY x.product_id
      ORDER BY x.product_id
    LOOP
      SELECT price INTO v_product
        FROM public.products
       WHERE id = v_item.product_id AND supplier_id = v_supplier_id;
      v_supplier_total := v_supplier_total + (v_product.price * v_item.quantity);
    END LOOP;

    INSERT INTO public.orders (
      customer_id, supplier_id, total_amount, subtotal, status,
      payment_method, payment_status, delivery_address, notes
    ) VALUES (
      v_customer_id, v_supplier_id, v_supplier_total, v_supplier_total, 'انتظار قبول',
      p_payment_method,
      CASE WHEN p_payment_method IN ('محفظة كاش','من الرصيد') THEN 'paid' ELSE 'pending' END,
      btrim(p_delivery_address), NULLIF(btrim(COALESCE(p_notes,'')), '')
    )
    RETURNING id INTO v_order_id;

    v_order_ids := v_order_ids || jsonb_build_array(v_order_id);

    INSERT INTO public.order_status_history(order_id, status, changed_by, note)
    VALUES (v_order_id, 'انتظار قبول', v_customer_id, 'تم إنشاء الطلب');

    FOR v_item IN
      SELECT x.product_id, SUM(x.quantity)::NUMERIC(12,3) AS quantity
      FROM jsonb_to_recordset(p_items) AS x(supplier_id UUID, product_id BIGINT, quantity NUMERIC)
      WHERE x.supplier_id = v_supplier_id
      GROUP BY x.product_id
      ORDER BY x.product_id
    LOOP
      SELECT price, name, unit
        INTO v_product
        FROM public.products
       WHERE id = v_item.product_id AND supplier_id = v_supplier_id;

      INSERT INTO public.order_items (
        order_id, product_id, product_name, unit, quantity,
        unit_price, line_total, total_price
      ) VALUES (
        v_order_id, v_item.product_id, v_product.name, COALESCE(v_product.unit,'وحدة'),
        v_item.quantity, v_product.price, v_product.price * v_item.quantity,
        v_product.price * v_item.quantity
      );

      UPDATE public.products
         SET stock_quantity = CASE
           WHEN track_inventory THEN stock_quantity - v_item.quantity
           ELSE stock_quantity
         END,
         updated_at = NOW()
       WHERE id = v_item.product_id AND supplier_id = v_supplier_id;
    END LOOP;
  END LOOP;

  v_is_wallet_payment := p_payment_method IN ('محفظة كاش','من الرصيد');
  IF v_is_wallet_payment THEN
    SELECT id, balance
      INTO v_wallet_id, v_balance
      FROM public.wallets
     WHERE user_id = v_customer_id
     FOR UPDATE;

    IF NOT FOUND THEN
      RAISE EXCEPTION 'لا توجد محفظة نشطة لهذا الحساب';
    END IF;

    IF v_balance < v_total THEN
      RAISE EXCEPTION 'رصيد المحفظة غير كافٍ لإتمام الطلب';
    END IF;

    UPDATE public.wallets
       SET balance = balance - v_total, updated_at = NOW()
     WHERE id = v_wallet_id;

    IF v_total > 0 THEN
      INSERT INTO public.wallet_transactions (
        wallet_id, user_id, amount, transaction_type, status,
        reference, description, metadata
      ) VALUES (
        v_wallet_id, v_customer_id, -v_total, 'order_payment', 'completed',
        v_reference, 'دفع سلة سلسلة', jsonb_build_object('order_ids', v_order_ids)
      );
    END IF;
  END IF;

  SELECT COALESCE(jsonb_agg(to_jsonb(o) ORDER BY o.id), '[]'::JSONB)
    INTO v_orders
    FROM public.orders o
   WHERE o.id IN (SELECT value::BIGINT FROM jsonb_array_elements_text(v_order_ids));

  RETURN v_orders;
END;
$$;

REVOKE ALL ON FUNCTION public.place_multi_supplier_checkout(JSONB, TEXT, TEXT, TEXT) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.place_multi_supplier_checkout(JSONB, TEXT, TEXT, TEXT) TO authenticated;

COMMIT;
