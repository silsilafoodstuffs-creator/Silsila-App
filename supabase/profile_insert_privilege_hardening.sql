-- Prevent clients from inserting profile rows or assigning initial role/status/points.
-- Trusted SECURITY DEFINER auth.users triggers create profile rows. The Flutter app
-- updates allowed profile fields and does not perform direct profile INSERTs.
BEGIN;

REVOKE INSERT ON TABLE public.profiles FROM authenticated;
REVOKE INSERT (
  id, full_name, phone, account_type, governorate, district, address, created_at,
  whatsapp_phone, activity_type, customer_type, supplier_type, delegate_type,
  area, landmark, avatar_url, account_status, role, points_balance, updated_at
) ON public.profiles FROM authenticated;

COMMIT;

-- Verify: both has_table_privilege('authenticated','public.profiles','INSERT')
-- and has_column_privilege('authenticated','public.profiles','role','INSERT')
-- should return false; SELECT/UPDATE grants used by ProfileService remain intact.
