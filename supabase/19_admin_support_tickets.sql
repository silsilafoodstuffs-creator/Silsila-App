-- Administrator support queue with status and reply tracking.
BEGIN;

ALTER TABLE public.support_tickets
  ADD COLUMN IF NOT EXISTS admin_reply TEXT,
  ADD COLUMN IF NOT EXISTS resolved_at TIMESTAMPTZ;

CREATE OR REPLACE FUNCTION public.admin_list_support_tickets()
RETURNS TABLE (
  id UUID,
  user_id UUID,
  full_name TEXT,
  subject TEXT,
  message TEXT,
  category TEXT,
  status TEXT,
  priority TEXT,
  order_id BIGINT,
  admin_reply TEXT,
  created_at TIMESTAMPTZ,
  updated_at TIMESTAMPTZ
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
  SELECT t.id, t.user_id, p.full_name, t.subject, t.message, t.category,
         t.status, t.priority, t.order_id, t.admin_reply, t.created_at, t.updated_at
  FROM public.support_tickets t
  JOIN public.profiles p ON p.id = t.user_id
  WHERE t.status NOT IN ('resolved','closed')
  ORDER BY CASE t.priority WHEN 'urgent' THEN 0 WHEN 'high' THEN 1 ELSE 2 END,
           t.created_at ASC
  LIMIT 300;
END;
$$;

CREATE OR REPLACE FUNCTION public.admin_update_support_ticket(
  p_ticket_id UUID,
  p_status TEXT,
  p_reply TEXT DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_admin_id UUID := auth.uid();
  v_user_id UUID;
  v_subject TEXT;
  v_status TEXT;
  v_reply TEXT := NULLIF(btrim(COALESCE(p_reply,'')), '');
  v_ticket JSONB;
BEGIN
  IF v_admin_id IS NULL OR NOT EXISTS (
    SELECT 1 FROM public.profiles p WHERE p.id = v_admin_id AND p.role = 'admin'
  ) THEN
    RAISE EXCEPTION 'هذه العملية متاحة لإدارة النشاط فقط';
  END IF;

  IF p_status NOT IN ('open','in_progress','resolved','closed') THEN
    RAISE EXCEPTION 'حالة تذكرة الدعم غير مدعومة';
  END IF;

  SELECT user_id, subject INTO v_user_id, v_subject
    FROM public.support_tickets WHERE id = p_ticket_id FOR UPDATE;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'تذكرة الدعم غير موجودة';
  END IF;

  UPDATE public.support_tickets
     SET status = p_status,
         admin_reply = COALESCE(v_reply, admin_reply),
         assigned_to = v_admin_id,
         resolved_at = CASE WHEN p_status IN ('resolved','closed') THEN NOW() ELSE NULL END,
         updated_at = NOW()
   WHERE id = p_ticket_id
   RETURNING to_jsonb(support_tickets.*) INTO v_ticket;

  IF v_reply IS NOT NULL OR p_status IN ('resolved','closed') THEN
    INSERT INTO public.notifications (
      user_id, title, body, notification_type, type, data
    ) VALUES (
      v_user_id,
      'تحديث تذكرة الدعم',
      CASE WHEN v_reply IS NOT NULL THEN v_reply ELSE 'تم تحديث حالة تذكرتك: ' || p_status END,
      'support', 'support',
      jsonb_build_object('ticket_id', p_ticket_id, 'status', p_status, 'subject', v_subject)
    );
  END IF;

  RETURN v_ticket;
END;
$$;

REVOKE ALL ON FUNCTION public.admin_list_support_tickets() FROM PUBLIC;
REVOKE ALL ON FUNCTION public.admin_update_support_ticket(UUID, TEXT, TEXT) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.admin_list_support_tickets() TO authenticated;
GRANT EXECUTE ON FUNCTION public.admin_update_support_ticket(UUID, TEXT, TEXT) TO authenticated;

COMMIT;
