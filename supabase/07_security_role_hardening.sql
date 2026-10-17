-- Prevent self-registration as "إدارة نشاط" from granting administrator privileges.
BEGIN;

CREATE OR REPLACE FUNCTION public.silsila_sync_profile_role()
RETURNS TRIGGER
LANGUAGE plpgsql
SET search_path = public
AS $$
BEGIN
  NEW.role := CASE
    WHEN NEW.account_type IN ('مورد', 'supplier') THEN 'supplier'
    WHEN NEW.account_type IN ('مندوب', 'delegate') THEN 'delegate'
    WHEN NEW.account_type IN ('شركة شحن', 'shipping_company') THEN 'shipping_company'
    WHEN NEW.account_type IN ('إدارة نشاط', 'management')
         AND NEW.role = 'admin' THEN 'admin'
    WHEN NEW.account_type IN ('إدارة نشاط', 'management') THEN 'management'
    ELSE 'customer'
  END;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS silsila_profiles_role_compatibility ON public.profiles;
CREATE TRIGGER silsila_profiles_role_compatibility
BEFORE INSERT OR UPDATE OF account_type, role ON public.profiles
FOR EACH ROW EXECUTE FUNCTION public.silsila_sync_profile_role();

-- Existing self-selected management accounts must not retain administrator rights.
-- Trusted operators can promote the intended administrator directly in Supabase SQL Editor.
UPDATE public.profiles
   SET role = 'management'
 WHERE account_type IN ('إدارة نشاط', 'management')
   AND role = 'admin';

COMMIT;
