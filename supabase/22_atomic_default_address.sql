-- Set a user's default address atomically so a failed second write cannot clear all defaults.
BEGIN;

CREATE OR REPLACE FUNCTION public.set_default_address(p_address_id UUID)
RETURNS BOOLEAN
LANGUAGE plpgsql
SECURITY INVOKER
SET search_path = public
AS $$
DECLARE
  v_user_id UUID := auth.uid();
BEGIN
  IF v_user_id IS NULL THEN
    RAISE EXCEPTION 'يجب تسجيل الدخول أولاً';
  END IF;

  -- Coordinate this operation with the atomic insert/update function in migration 23.
  PERFORM pg_advisory_xact_lock(hashtextextended(v_user_id::TEXT, 0));

  IF NOT EXISTS (
    SELECT 1
    FROM public.addresses a
    WHERE a.id = p_address_id
      AND a.user_id = v_user_id
  ) THEN
    RAISE EXCEPTION 'العنوان غير موجود أو لا تملك صلاحية تعديله';
  END IF;

  UPDATE public.addresses
     SET is_default = FALSE
   WHERE user_id = v_user_id
     AND is_default = TRUE;

  UPDATE public.addresses
     SET is_default = TRUE
   WHERE id = p_address_id
     AND user_id = v_user_id;

  RETURN TRUE;
END;
$$;

REVOKE ALL ON FUNCTION public.set_default_address(UUID) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.set_default_address(UUID) TO authenticated;

COMMIT;
