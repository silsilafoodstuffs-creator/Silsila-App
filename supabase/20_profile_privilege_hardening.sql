-- Harden profile role and approval fields against self-promotion.
BEGIN;

CREATE OR REPLACE FUNCTION public.silsila_sync_profile_role()
RETURNS TRIGGER
LANGUAGE plpgsql
SET search_path = public
AS $$
DECLARE
  v_is_self_update BOOLEAN := FALSE;
  v_is_admin_actor BOOLEAN := FALSE;
BEGIN
  v_is_self_update := auth.uid() IS NOT NULL AND auth.uid() = NEW.id;

  IF auth.uid() IS NOT NULL THEN
    SELECT EXISTS (
      SELECT 1 FROM public.profiles p
      WHERE p.id = auth.uid() AND p.role = 'admin'
    ) INTO v_is_admin_actor;
  END IF;

  IF TG_OP = 'UPDATE' AND OLD.role = 'admin' THEN
    -- An existing trusted administrator retains the role; a non-admin cannot acquire it here.
    NEW.role := 'admin';
  ELSE
    NEW.role := CASE
      WHEN NEW.account_type IN ('مورد', 'supplier') THEN 'supplier'
      WHEN NEW.account_type IN ('مندوب', 'delegate') THEN 'delegate'
      WHEN NEW.account_type IN ('شركة شحن', 'shipping_company') THEN 'shipping_company'
      WHEN NEW.account_type IN ('إدارة نشاط', 'management', 'admin') THEN 'management'
      ELSE 'customer'
    END;
  END IF;

  IF TG_OP = 'INSERT' THEN
    IF v_is_self_update THEN
      NEW.account_status := 'pending';
    ELSE
      NEW.account_status := COALESCE(NULLIF(NEW.account_status, ''), 'pending');
    END IF;
  ELSIF v_is_self_update AND NOT v_is_admin_actor THEN
    NEW.account_status := OLD.account_status;
  END IF;

  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS silsila_profiles_role_compatibility ON public.profiles;
CREATE TRIGGER silsila_profiles_role_compatibility
BEFORE INSERT OR UPDATE OF account_type, role, account_status ON public.profiles
FOR EACH ROW EXECUTE FUNCTION public.silsila_sync_profile_role();

-- Force existing self-selected management accounts to remain non-admin.
UPDATE public.profiles
   SET role = 'management'
 WHERE account_type IN ('إدارة نشاط', 'management', 'admin')
   AND role <> 'admin';

COMMIT;
