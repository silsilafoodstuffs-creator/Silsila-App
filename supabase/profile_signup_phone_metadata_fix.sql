-- Silsila profile signup hardening.
-- Keep one canonical auth.users trigger and preserve phone metadata for
-- email/password signups where auth.users.phone is null.
-- Existing profiles are not rewritten by this migration.

BEGIN;

CREATE OR REPLACE FUNCTION public.silsila_handle_new_user()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $function$
BEGIN
  INSERT INTO public.profiles (
    id, full_name, phone, whatsapp_phone, account_type, activity_type,
    customer_type, supplier_type, delegate_type, governorate, district,
    area, address, landmark, account_status
  ) VALUES (
    NEW.id,
    COALESCE(NEW.raw_user_meta_data->>'full_name', ''),
    COALESCE(
      NULLIF(btrim(COALESCE(NEW.phone, '')), ''),
      NULLIF(btrim(COALESCE(NEW.raw_user_meta_data->>'phone', '')), '')
    ),
    NEW.raw_user_meta_data->>'whatsapp_phone',
    COALESCE(NEW.raw_user_meta_data->>'account_type', 'عميل'),
    COALESCE(NEW.raw_user_meta_data->>'activity_type', 'مواد غذائية'),
    NEW.raw_user_meta_data->>'customer_type',
    NEW.raw_user_meta_data->>'supplier_type',
    NEW.raw_user_meta_data->>'delegate_type',
    NEW.raw_user_meta_data->>'governorate',
    NEW.raw_user_meta_data->>'district',
    NEW.raw_user_meta_data->>'area',
    NEW.raw_user_meta_data->>'address',
    NEW.raw_user_meta_data->>'landmark',
    'pending'
  )
  ON CONFLICT (id) DO UPDATE SET
    full_name = COALESCE(NULLIF(EXCLUDED.full_name, ''), public.profiles.full_name),
    phone = COALESCE(EXCLUDED.phone, public.profiles.phone),
    whatsapp_phone = COALESCE(EXCLUDED.whatsapp_phone, public.profiles.whatsapp_phone),
    account_type = EXCLUDED.account_type,
    activity_type = EXCLUDED.activity_type,
    customer_type = COALESCE(EXCLUDED.customer_type, public.profiles.customer_type),
    supplier_type = COALESCE(EXCLUDED.supplier_type, public.profiles.supplier_type),
    delegate_type = COALESCE(EXCLUDED.delegate_type, public.profiles.delegate_type),
    governorate = COALESCE(EXCLUDED.governorate, public.profiles.governorate),
    district = COALESCE(EXCLUDED.district, public.profiles.district),
    area = COALESCE(EXCLUDED.area, public.profiles.area),
    address = COALESCE(EXCLUDED.address, public.profiles.address),
    landmark = COALESCE(EXCLUDED.landmark, public.profiles.landmark),
    updated_at = NOW();

  RETURN NEW;
END;
$function$;

-- Avoid running a legacy profile insert before the canonical upsert trigger.
DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;

COMMIT;

-- Verify that only the canonical trigger remains:
-- SELECT t.tgname, p.proname
-- FROM pg_trigger t
-- JOIN pg_class c ON c.oid = t.tgrelid
-- JOIN pg_namespace n ON n.oid = c.relnamespace
-- JOIN pg_proc p ON p.oid = t.tgfoid
-- WHERE NOT t.tgisinternal AND n.nspname = 'auth' AND c.relname = 'users';
