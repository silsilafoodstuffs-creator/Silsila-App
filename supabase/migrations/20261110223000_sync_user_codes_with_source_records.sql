-- Keep user codes synchronized with the inherited type digits and linked employee suffix.
-- This changes only derived user_code values when their source code changes.

CREATE OR REPLACE FUNCTION private.erp_assign_user_code()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO ''
AS $function$
DECLARE
  v_type_code_display text;
  v_type_code bigint;
  v_type_name_ar text;
  v_type_name_en text;
  v_type_digits text;
  v_user_prefix text;
  v_employee_code text;
  v_employee_digits text;
  v_suffix text;
  v_expected text;
  v_max bigint;
  v_lock text;
BEGIN
  IF NEW.user_type_id IS NULL THEN
    RAISE EXCEPTION 'يجب تحديد نوع المستخدم قبل توليد كود المستخدم';
  END IF;

  SELECT t.type_code_display,t.type_code,t.name_ar,t.name_en
    INTO v_type_code_display,v_type_code,v_type_name_ar,v_type_name_en
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

  IF lower(btrim(coalesce(v_type_name_ar,'')))='موظف'
     OR lower(btrim(coalesce(v_type_name_en,'')))='employee' THEN
    IF NEW.employee_id IS NULL THEN
      RAISE EXCEPTION 'يجب ربط مستخدم نوع «موظف» بملف موظف نشط';
    END IF;

    SELECT e.employee_code INTO v_employee_code
    FROM public.erp_employees e
    WHERE e.id=NEW.employee_id
      AND e.company_id=NEW.company_id
      AND e.is_active=true;

    IF NOT FOUND THEN
      RAISE EXCEPTION 'الموظف المرتبط غير موجود أو غير نشط في الشركة الحالية';
    END IF;

    v_employee_digits:=regexp_replace(coalesce(v_employee_code,''),'[^0-9]','','g');
    IF length(v_employee_digits)<5 THEN
      RAISE EXCEPTION 'كود الموظف المرتبط يجب أن يحتوي على خمسة أرقام على الأقل';
    END IF;

    v_suffix:=right(v_employee_digits,5);
    v_expected:=v_user_prefix||v_type_digits||v_suffix;

    IF TG_OP='UPDATE'
       AND NEW.user_type_id IS NOT DISTINCT FROM OLD.user_type_id
       AND NEW.employee_id IS NOT DISTINCT FROM OLD.employee_id
       AND NEW.user_code IS NOT DISTINCT FROM v_expected THEN
      RETURN NEW;
    END IF;
  ELSE
    IF TG_OP='UPDATE'
       AND NEW.user_type_id IS NOT DISTINCT FROM OLD.user_type_id
       AND NEW.employee_id IS NOT DISTINCT FROM OLD.employee_id
       AND NEW.user_code ~ ('^'||v_user_prefix||v_type_digits||'[0-9]{5}$') THEN
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
  END IF;

  NEW.user_code:=v_user_prefix||v_type_digits||v_suffix;
  RETURN NEW;
END;
$function$;

REVOKE ALL ON FUNCTION private.erp_assign_user_code() FROM PUBLIC,anon,authenticated;

CREATE OR REPLACE FUNCTION private.erp_sync_linked_user_codes()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO ''
AS $function$
BEGIN
  IF TG_TABLE_NAME='erp_employees' THEN
    IF NEW.employee_code IS DISTINCT FROM OLD.employee_code THEN
      UPDATE public.erp_users
      SET user_code=NULL
      WHERE company_id=NEW.company_id
        AND employee_id=NEW.id
        AND user_code IS NOT NULL;
    END IF;
  ELSIF TG_TABLE_NAME='erp_user_types' THEN
    IF NEW.type_code_display IS DISTINCT FROM OLD.type_code_display
       OR NEW.name_ar IS DISTINCT FROM OLD.name_ar
       OR NEW.name_en IS DISTINCT FROM OLD.name_en THEN
      UPDATE public.erp_users
      SET user_code=NULL
      WHERE company_id=NEW.company_id
        AND user_type_id=NEW.id
        AND user_code IS NOT NULL;
    END IF;
  END IF;
  RETURN NEW;
END;
$function$;

REVOKE ALL ON FUNCTION private.erp_sync_linked_user_codes() FROM PUBLIC,anon,authenticated;

DROP TRIGGER IF EXISTS erp_employees_sync_linked_user_codes ON public.erp_employees;
CREATE TRIGGER erp_employees_sync_linked_user_codes
AFTER UPDATE OF employee_code ON public.erp_employees
FOR EACH ROW
WHEN (OLD.employee_code IS DISTINCT FROM NEW.employee_code)
EXECUTE FUNCTION private.erp_sync_linked_user_codes();

DROP TRIGGER IF EXISTS erp_user_types_sync_linked_user_codes ON public.erp_user_types;
CREATE TRIGGER erp_user_types_sync_linked_user_codes
AFTER UPDATE OF type_code_display,name_ar,name_en ON public.erp_user_types
FOR EACH ROW
WHEN (
  OLD.type_code_display IS DISTINCT FROM NEW.type_code_display
  OR OLD.name_ar IS DISTINCT FROM NEW.name_ar
  OR OLD.name_en IS DISTINCT FROM NEW.name_en
)
EXECUTE FUNCTION private.erp_sync_linked_user_codes();


-- When the central user-type policy changes, refresh the derived type display
-- codes; the user-type trigger then synchronizes each dependent user code.
CREATE OR REPLACE FUNCTION private.erp_refresh_user_type_codes_from_policy()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO ''
AS $function$
BEGIN
  IF NEW.policy_key='code_generation_registry' THEN
    UPDATE public.erp_user_types
    SET type_code_display=type_code_display
    WHERE company_id=NEW.company_id;
  END IF;
  RETURN NEW;
END;
$function$;

REVOKE ALL ON FUNCTION private.erp_refresh_user_type_codes_from_policy() FROM PUBLIC,anon,authenticated;

DROP TRIGGER IF EXISTS erp_program_policies_refresh_user_type_codes ON public.erp_program_policies;
CREATE TRIGGER erp_program_policies_refresh_user_type_codes
AFTER INSERT OR UPDATE OF policy_key,policy_value
ON public.erp_program_policies
FOR EACH ROW
WHEN (NEW.policy_key='code_generation_registry')
EXECUTE FUNCTION private.erp_refresh_user_type_codes_from_policy();
