BEGIN;

-- User identifiers inherit only the numeric user-type code.
-- Employee linkage remains a separate relationship and never supplies user-code digits.
CREATE OR REPLACE FUNCTION private.erp_assign_user_code()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO ''
AS $function$
DECLARE
  v_type_code_display text;
  v_type_code bigint;
  v_type_digits text;
  v_user_prefix text;
  v_suffix text;
  v_max bigint;
  v_lock text;
BEGIN
  IF NEW.user_type_id IS NULL THEN
    RAISE EXCEPTION 'يجب تحديد نوع المستخدم قبل توليد كود المستخدم';
  END IF;

  SELECT t.type_code_display,t.type_code
    INTO v_type_code_display,v_type_code
  FROM public.erp_user_types t
  WHERE t.id=NEW.user_type_id AND t.company_id=NEW.company_id;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'نوع المستخدم المحدد غير موجود في الشركة الحالية';
  END IF;

  SELECT c.prefix INTO v_user_prefix
  FROM public.erp_code_policy_config(NEW.company_id,'user','Usr',5) c;

  v_type_digits:=regexp_replace(coalesce(v_type_code_display,''),'[^0-9]','','g');
  IF v_type_digits='' THEN
    v_type_digits:=lpad(v_type_code::text,2,'0');
  END IF;

  -- Preserve a valid already-issued code for this same user type.
  IF NEW.user_code ~ ('^'||v_user_prefix||v_type_digits||'[0-9]{5}$') THEN
    RETURN NEW;
  END IF;

  v_lock:=NEW.company_id::text||':user:'||NEW.user_type_id::text;
  PERFORM pg_advisory_xact_lock(hashtextextended(v_lock,0));

  SELECT coalesce(max(right(u.user_code,5)::bigint),0)
    INTO v_max
  FROM public.erp_users u
  WHERE u.company_id=NEW.company_id
    AND u.user_type_id=NEW.user_type_id
    AND u.id IS DISTINCT FROM NEW.id
    AND u.user_code ~ ('^'||v_user_prefix||v_type_digits||'[0-9]{5}$');

  IF coalesce(v_max,0)>=99999 THEN
    RAISE EXCEPTION 'انتهت خانات المستخدم لهذا النوع؛ راجع سياسة التكويد';
  END IF;

  v_suffix:=lpad((coalesce(v_max,0)+1)::text,5,'0');
  NEW.user_code:=v_user_prefix||v_type_digits||v_suffix;
  RETURN NEW;
END;
$function$;

REVOKE ALL ON FUNCTION private.erp_assign_user_code() FROM PUBLIC,anon,authenticated;

-- Employee code changes must not regenerate or renumber linked user codes.
DROP TRIGGER IF EXISTS erp_employees_sync_linked_user_codes ON public.erp_employees;

-- Employee linkage is not a code source; it is not part of the user-code trigger's event columns.
DROP TRIGGER IF EXISTS erp_users_central_code ON public.erp_users;
CREATE TRIGGER erp_users_central_code
BEFORE INSERT OR UPDATE OF user_type_id,user_code
ON public.erp_users
FOR EACH ROW
EXECUTE FUNCTION private.erp_assign_user_code();

COMMIT;
