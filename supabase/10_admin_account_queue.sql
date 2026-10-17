-- Return only minimal fields required for administrator account review.
BEGIN;

CREATE OR REPLACE FUNCTION public.admin_list_pending_accounts()
RETURNS TABLE (
  id UUID,
  full_name TEXT,
  phone TEXT,
  account_type TEXT,
  activity_type TEXT,
  governorate TEXT,
  district TEXT,
  created_at TIMESTAMPTZ
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF auth.uid() IS NULL OR NOT EXISTS (
    SELECT 1 FROM public.profiles p
    WHERE p.id = auth.uid() AND p.role = 'admin'
  ) THEN
    RAISE EXCEPTION 'هذه العملية متاحة لإدارة النشاط فقط';
  END IF;

  RETURN QUERY
  SELECT p.id, p.full_name, p.phone, p.account_type, p.activity_type,
         p.governorate, p.district, p.created_at
  FROM public.profiles p
  WHERE p.account_status = 'pending'
  ORDER BY p.created_at ASC
  LIMIT 200;
END;
$$;

REVOKE ALL ON FUNCTION public.admin_list_pending_accounts() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.admin_list_pending_accounts() TO authenticated;

COMMIT;
