-- User codes inherit the numeric user-type code; employee users reuse the linked employee's 5-digit suffix.
-- Existing user_code values are intentionally preserved.

CREATE OR REPLACE FUNCTION public.erp_set_user_type_display_code()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO ''
AS $function$
DECLARE
  v_prefix text;
  v_digits integer;
BEGIN
  SELECT c.prefix, c.digits
    INTO v_prefix, v_digits
  FROM public.erp_code_policy_config(new.company_id, 'user_type', 'Typ', 2) c;

  IF new.type_code IS NULL OR new.type_code < 0 THEN
    RAISE EXCEPTION 'رقم نوع المستخدم غير صالح';
  END IF;
  IF new.type_code >= power(10::numeric, v_digits) THEN
    RAISE EXCEPTION 'انتهت خانات كود نوع المستخدم؛ زد عدد الخانات من سياسات التكويد';
  END IF;

  new.type_code_display := v_prefix || lpad(new.type_code::text, v_digits, '0');
  RETURN new;
END;
$function$;

-- Re-render existing derived type codes according to each company's saved policy.
-- Numeric type_code values and foreign keys remain unchanged.
DROP TRIGGER IF EXISTS erp_user_types_central_display_code ON public.erp_user_types;
CREATE TRIGGER erp_user_types_central_display_code
BEFORE INSERT OR UPDATE OF company_id, type_code, type_code_display
ON public.erp_user_types
FOR EACH ROW
EXECUTE FUNCTION public.erp_set_user_type_display_code();

-- Refresh only the derived display column; type_code is GENERATED ALWAYS identity.
UPDATE public.erp_user_types
SET type_code_display = type_code_display;

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
  v_suffix text;
  v_max bigint;
  v_lock text;
BEGIN
  -- Keep existing codes unless the user type or employee link is changed.
  IF TG_OP = 'UPDATE' THEN
    IF NEW.user_type_id IS NOT DISTINCT FROM OLD.user_type_id
       AND NEW.employee_id IS NOT DISTINCT FROM OLD.employee_id THEN
      RETURN NEW;
    END IF;
  ELSIF nullif(NEW.user_code, '') IS NOT NULL THEN
    RETURN NEW;
  END IF;

  IF NEW.user_type_id IS NULL THEN
    RAISE EXCEPTION 'يجب تحديد نوع المستخدم قبل توليد كود المستخدم';
  END IF;

  SELECT t.type_code_display, t.type_code, t.name_ar, t.name_en
    INTO v_type_code_display, v_type_code, v_type_name_ar, v_type_name_en
  FROM public.erp_user_types t
  WHERE t.id = NEW.user_type_id
    AND t.company_id = NEW.company_id;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'نوع المستخدم المحدد غير موجود في الشركة الحالية';
  END IF;

  -- Remove every English prefix character; only the numeric type code is inherited.
  v_type_digits := regexp_replace(coalesce(v_type_code_display, ''), '[^0-9]', '', 'g');
  IF v_type_digits = '' THEN
    v_type_digits := lpad(v_type_code::text, 2, '0');
  END IF;

  SELECT c.prefix
    INTO v_user_prefix
  FROM public.erp_code_policy_config(NEW.company_id, 'user', 'Usr', 5) c;

  IF lower(btrim(coalesce(v_type_name_ar, ''))) = 'موظف'
     OR lower(btrim(coalesce(v_type_name_en, ''))) = 'employee' THEN
    IF NEW.employee_id IS NULL THEN
      RAISE EXCEPTION 'يجب ربط مستخدم نوع «موظف» بملف موظف نشط';
    END IF;

    SELECT e.employee_code
      INTO v_employee_code
    FROM public.erp_employees e
    WHERE e.id = NEW.employee_id
      AND e.company_id = NEW.company_id
      AND e.is_active = true;

    IF NOT FOUND OR coalesce(v_employee_code, '') !~ '[0-9]{5}$' THEN
      RAISE EXCEPTION 'كود الموظف المرتبط يجب أن ينتهي بخمسة أرقام';
    END IF;

    -- The final five digits of an employee user's code exactly match employee_code.
    v_suffix := right(regexp_replace(v_employee_code, '[^0-9]', '', 'g'), 5);
  ELSE
    -- Non-employee user types receive their own 5-digit serial within that type.
    v_lock := NEW.company_id::text || ':user:' || NEW.user_type_id::text;
    PERFORM pg_advisory_xact_lock(hashtextextended(v_lock, 0));

    SELECT coalesce(max(right(u.user_code, 5)::bigint), 0)
      INTO v_max
    FROM public.erp_users u
    WHERE u.company_id = NEW.company_id
      AND u.user_type_id = NEW.user_type_id
      AND u.user_code ~ ('^' || v_user_prefix || v_type_digits || '[0-9]{5}$')
      AND (TG_OP <> 'UPDATE' OR u.id <> NEW.id);

    IF coalesce(v_max, 0) >= 99999 THEN
      RAISE EXCEPTION 'انتهت خانات المستخدم لهذا النوع؛ راجع سياسة التكويد';
    END IF;

    v_suffix := lpad((coalesce(v_max, 0) + 1)::text, 5, '0');
  END IF;

  NEW.user_code := v_user_prefix || v_type_digits || v_suffix;
  RETURN NEW;
END;
$function$;

REVOKE ALL ON FUNCTION private.erp_assign_user_code() FROM PUBLIC, anon, authenticated;

DROP TRIGGER IF EXISTS erp_users_central_code ON public.erp_users;
CREATE TRIGGER erp_users_central_code
BEFORE INSERT OR UPDATE OF user_type_id, employee_id
ON public.erp_users
FOR EACH ROW
EXECUTE FUNCTION private.erp_assign_user_code();
