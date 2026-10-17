-- Secure administrator review and posting of wallet top-ups.
BEGIN;

CREATE OR REPLACE FUNCTION public.admin_list_pending_topups()
RETURNS TABLE (
  id UUID,
  user_id UUID,
  full_name TEXT,
  amount NUMERIC,
  payment_method TEXT,
  reference TEXT,
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
  SELECT r.id, r.user_id, p.full_name, r.amount, r.payment_method, r.reference, r.created_at
  FROM public.wallet_topup_requests r
  JOIN public.profiles p ON p.id = r.user_id
  WHERE r.status = 'pending'
  ORDER BY r.created_at ASC
  LIMIT 200;
END;
$$;

CREATE OR REPLACE FUNCTION public.admin_review_wallet_topup(
  p_request_id UUID,
  p_approve BOOLEAN,
  p_note TEXT DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_admin_id UUID := auth.uid();
  v_user_id UUID;
  v_amount NUMERIC(12,2);
  v_status TEXT;
  v_method TEXT;
  v_reference TEXT;
  v_wallet_id UUID;
BEGIN
  IF v_admin_id IS NULL OR NOT EXISTS (
    SELECT 1 FROM public.profiles p WHERE p.id = v_admin_id AND p.role = 'admin'
  ) THEN
    RAISE EXCEPTION 'هذه العملية متاحة لإدارة النشاط فقط';
  END IF;

  SELECT user_id, amount, status, payment_method, reference
    INTO v_user_id, v_amount, v_status, v_method, v_reference
    FROM public.wallet_topup_requests
   WHERE id = p_request_id
   FOR UPDATE;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'طلب الشحن غير موجود';
  END IF;

  IF v_status <> 'pending' THEN
    RAISE EXCEPTION 'تمت مراجعة طلب الشحن من قبل';
  END IF;

  IF p_approve THEN
    INSERT INTO public.wallets(user_id, balance)
    VALUES (v_user_id, 0)
    ON CONFLICT (user_id) DO NOTHING;

    SELECT id INTO v_wallet_id
      FROM public.wallets
     WHERE user_id = v_user_id
     FOR UPDATE;

    UPDATE public.wallets
       SET balance = balance + v_amount, updated_at = NOW()
     WHERE id = v_wallet_id;

    INSERT INTO public.wallet_transactions (
      wallet_id, user_id, amount, transaction_type, status,
      reference, description, metadata
    ) VALUES (
      v_wallet_id, v_user_id, v_amount, 'topup', 'completed',
      COALESCE(NULLIF(btrim(COALESCE(v_reference,'')), ''), p_request_id::TEXT),
      'اعتماد طلب شحن المحفظة', jsonb_build_object('topup_request_id', p_request_id, 'payment_method', v_method)
    );
  END IF;

  UPDATE public.wallet_topup_requests
     SET status = CASE WHEN p_approve THEN 'approved' ELSE 'rejected' END,
         reviewed_by = v_admin_id,
         reviewed_at = NOW(),
         review_note = NULLIF(btrim(COALESCE(p_note,'')), '')
   WHERE id = p_request_id;

  RETURN jsonb_build_object(
    'id', p_request_id,
    'status', CASE WHEN p_approve THEN 'approved' ELSE 'rejected' END
  );
END;
$$;

REVOKE ALL ON FUNCTION public.admin_list_pending_topups() FROM PUBLIC;
REVOKE ALL ON FUNCTION public.admin_review_wallet_topup(UUID, BOOLEAN, TEXT) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.admin_list_pending_topups() TO authenticated;
GRANT EXECUTE ON FUNCTION public.admin_review_wallet_topup(UUID, BOOLEAN, TEXT) TO authenticated;

COMMIT;
