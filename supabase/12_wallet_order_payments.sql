-- Atomically debit the customer's internal wallet for wallet-funded orders.
-- The original secure order routine remains the source of price, stock and ownership checks.
BEGIN;

ALTER FUNCTION public.place_supplier_order(UUID, JSONB, TEXT, TEXT, TEXT)
  RENAME TO place_supplier_order_without_wallet;

REVOKE ALL ON FUNCTION public.place_supplier_order_without_wallet(UUID, JSONB, TEXT, TEXT, TEXT) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.place_supplier_order_without_wallet(UUID, JSONB, TEXT, TEXT, TEXT) FROM authenticated;

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
  v_order JSONB;
  v_order_id BIGINT;
  v_customer_id UUID := auth.uid();
  v_total NUMERIC(12,2);
  v_wallet_id UUID;
  v_balance NUMERIC(12,2);
BEGIN
  IF v_customer_id IS NULL THEN
    RAISE EXCEPTION 'يجب تسجيل الدخول أولاً';
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM public.profiles p
    WHERE p.id = p_supplier_id
      AND p.role = 'supplier'
      AND p.account_status IN ('approved', 'active', 'مفعل', 'معتمد')
  ) THEN
    RAISE EXCEPTION 'لا يمكن الطلب من مورد غير معتمد أو غير نشط';
  END IF;

  v_order := public.place_supplier_order_without_wallet(
    p_supplier_id, p_items, p_payment_method, p_delivery_address, p_notes
  );

  IF p_payment_method IN ('محفظة كاش', 'من الرصيد') THEN
    v_order_id := (v_order->>'id')::BIGINT;
    v_total := COALESCE((v_order->>'total_amount')::NUMERIC, 0);

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
       SET balance = balance - v_total,
           updated_at = NOW()
     WHERE id = v_wallet_id;

    UPDATE public.orders
       SET payment_status = 'paid',
           updated_at = NOW()
     WHERE id = v_order_id;

    IF v_total > 0 THEN
      INSERT INTO public.wallet_transactions (
        wallet_id, user_id, amount, transaction_type, status,
        reference, description, metadata
      ) VALUES (
        v_wallet_id, v_customer_id, -v_total, 'order_payment', 'completed',
        v_order_id::TEXT, 'دفع طلب سلسلة رقم ' || v_order_id,
        jsonb_build_object('order_id', v_order_id, 'supplier_id', p_supplier_id)
      );
    END IF;

    SELECT to_jsonb(o) INTO v_order
      FROM public.orders o
     WHERE o.id = v_order_id;
  END IF;

  RETURN v_order;
END;
$$;

REVOKE ALL ON FUNCTION public.place_supplier_order(UUID, JSONB, TEXT, TEXT, TEXT) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.place_supplier_order(UUID, JSONB, TEXT, TEXT, TEXT) TO authenticated;

COMMIT;
