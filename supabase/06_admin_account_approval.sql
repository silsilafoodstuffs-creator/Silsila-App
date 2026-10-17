-- Trusted administrative account approval; never permit self-service status changes.
BEGIN;

CREATE OR REPLACE FUNCTION public.admin_update_account_status(
  p_user_id UUID,
  p_status TEXT
)
RETURNS BOOLEAN
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_actor UUID := auth.uid();
BEGIN
  IF v_actor IS NULL THEN
    RAISE EXCEPTION 'يجب تسجيل الدخول أولاً';
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM public.profiles
    WHERE id = v_actor AND role = 'admin'
  ) THEN
    RAISE EXCEPTION 'هذه العملية متاحة لإدارة النشاط فقط';
  END IF;

  IF p_status NOT IN ('pending', 'approved', 'active', 'rejected', 'suspended', 'مفعل', 'معتمد', 'مرفوض', 'موقوف') THEN
    RAISE EXCEPTION 'حالة الحساب غير مدعومة';
  END IF;

  UPDATE public.profiles
     SET account_status = p_status,
         updated_at = NOW()
   WHERE id = p_user_id;

  RETURN FOUND;
END;
$$;

REVOKE ALL ON FUNCTION public.admin_update_account_status(UUID, TEXT) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.admin_update_account_status(UUID, TEXT) TO authenticated;

COMMIT;
