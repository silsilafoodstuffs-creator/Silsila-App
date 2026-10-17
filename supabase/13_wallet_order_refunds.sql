-- Refund wallet-funded orders atomically when a pending order is cancelled.
BEGIN;

CREATE OR REPLACE FUNCTION public.cancel_customer_order(p_order_id BIGINT)
RETURNS BOOLEAN
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_user_id UUID := auth.uid();
  v_current_status TEXT;
  v_payment_method TEXT;
  v_payment_status TEXT;
  v_total NUMERIC(12,2);
  v_wallet_id UUID;
BEGIN
  IF v_user_id IS NULL THEN
    RAISE EXCEPTION 'يجب تسجيل الدخول أولاً';
  END IF;

  SELECT status, payment_method, payment_status, total_amount
    INTO v_current_status, v_payment_method, v_payment_status, v_total
    FROM public.orders
   WHERE id = p_order_id AND customer_id = v_user_id
   FOR UPDATE;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'الطلب غير موجود أو لا تملك صلاحية إلغائه';
  END IF;

  IF v_current_status <> 'انتظار قبول' THEN
    RAISE EXCEPTION 'لا يمكن إلغاء الطلب بعد بدء تنفيذه';
  END IF;

  IF v_payment_method IN ('محفظة كاش', 'من الرصيد') AND v_payment_status = 'paid' THEN
    SELECT id INTO v_wallet_id
      FROM public.wallets
     WHERE user_id = v_user_id
     FOR UPDATE;

    IF v_wallet_id IS NULL THEN
      RAISE EXCEPTION 'تعذر العثور على المحفظة لإرجاع المبلغ';
    END IF;

    UPDATE public.wallets
       SET balance = balance + v_total, updated_at = NOW()
     WHERE id = v_wallet_id;

    IF v_total > 0 THEN
      INSERT INTO public.wallet_transactions (
        wallet_id, user_id, amount, transaction_type, status,
        reference, description, metadata
      ) VALUES (
        v_wallet_id, v_user_id, v_total, 'order_refund', 'completed',
        p_order_id::TEXT, 'استرداد قيمة الطلب الملغي رقم ' || p_order_id,
        jsonb_build_object('order_id', p_order_id)
      );
    END IF;

    UPDATE public.orders SET payment_status = 'refunded' WHERE id = p_order_id;
  END IF;

  UPDATE public.orders SET status = 'مُلغي', updated_at = NOW()
   WHERE id = p_order_id;

  INSERT INTO public.order_status_history(order_id, status, changed_by, note)
  VALUES (p_order_id, 'مُلغي', v_user_id, 'إلغاء بواسطة العميل');

  RETURN TRUE;
END;
$$;

CREATE OR REPLACE FUNCTION public.transition_supplier_order_status(
  p_order_id BIGINT,
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
  v_customer_id UUID;
  v_current_status TEXT;
  v_payment_method TEXT;
  v_payment_status TEXT;
  v_total NUMERIC(12,2);
  v_wallet_id UUID;
  v_order JSONB;
  v_allowed BOOLEAN := FALSE;
BEGIN
  IF v_user_id IS NULL THEN
    RAISE EXCEPTION 'يجب تسجيل الدخول أولاً';
  END IF;

  SELECT status, customer_id, payment_method, payment_status, total_amount
    INTO v_current_status, v_customer_id, v_payment_method, v_payment_status, v_total
    FROM public.orders
   WHERE id = p_order_id AND supplier_id = v_user_id
   FOR UPDATE;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'الطلب غير موجود أو لا تملك صلاحية تحديثه';
  END IF;

  v_allowed := CASE v_current_status
    WHEN 'انتظار قبول' THEN p_new_status IN ('تنفيذ','مُلغي')
    WHEN 'تنفيذ' THEN p_new_status IN ('تحميل','مُلغي')
    WHEN 'تحميل' THEN p_new_status = 'توصيل'
    WHEN 'توصيل' THEN p_new_status = 'تم التسليم'
    ELSE FALSE
  END;

  IF NOT v_allowed THEN
    RAISE EXCEPTION 'لا يمكن نقل الطلب من % إلى %', v_current_status, p_new_status;
  END IF;

  IF p_new_status = 'مُلغي'
     AND v_payment_method IN ('محفظة كاش', 'من الرصيد')
     AND v_payment_status = 'paid' THEN
    SELECT id INTO v_wallet_id
      FROM public.wallets
     WHERE user_id = v_customer_id
     FOR UPDATE;

    IF v_wallet_id IS NULL THEN
      RAISE EXCEPTION 'تعذر العثور على محفظة العميل لإرجاع المبلغ';
    END IF;

    UPDATE public.wallets
       SET balance = balance + v_total, updated_at = NOW()
     WHERE id = v_wallet_id;

    IF v_total > 0 THEN
      INSERT INTO public.wallet_transactions (
        wallet_id, user_id, amount, transaction_type, status,
        reference, description, metadata
      ) VALUES (
        v_wallet_id, v_customer_id, v_total, 'order_refund', 'completed',
        p_order_id::TEXT, 'استرداد قيمة الطلب الملغي رقم ' || p_order_id,
        jsonb_build_object('order_id', p_order_id, 'cancelled_by', v_user_id)
      );
    END IF;

    UPDATE public.orders SET payment_status = 'refunded' WHERE id = p_order_id;
  END IF;

  UPDATE public.orders
     SET status = p_new_status, updated_at = NOW()
   WHERE id = p_order_id
   RETURNING to_jsonb(orders.*) INTO v_order;

  INSERT INTO public.order_status_history(order_id, status, changed_by, note)
  VALUES (p_order_id, p_new_status, v_user_id, NULLIF(btrim(COALESCE(p_note,'')), ''));

  RETURN v_order;
END;
$$;

REVOKE ALL ON FUNCTION public.transition_supplier_order_status(BIGINT, TEXT, TEXT) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.cancel_customer_order(BIGINT) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.transition_supplier_order_status(BIGINT, TEXT, TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION public.cancel_customer_order(BIGINT) TO authenticated;

COMMIT;
