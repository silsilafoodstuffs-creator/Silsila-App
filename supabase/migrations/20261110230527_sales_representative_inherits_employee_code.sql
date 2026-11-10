CREATE OR REPLACE FUNCTION private.erp_assign_sales_representative_code()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO ''
AS $function$
DECLARE
  v_employee_code text;
  v_employee_prefix text;
  v_employee_digits integer;
  v_employee_suffix text;
  v_rep_prefix text;
  v_rep_digits integer;
  v_candidate text;
BEGIN
  IF TG_OP='UPDATE'
     AND NEW.employee_id IS NOT DISTINCT FROM OLD.employee_id
     AND NEW.rep_code IS NOT DISTINCT FROM OLD.rep_code THEN
    RETURN NEW;
  END IF;

  IF TG_OP='INSERT' AND nullif(btrim(NEW.rep_code),'') IS NOT NULL THEN
    RETURN NEW;
  END IF;

  IF TG_OP='UPDATE'
     AND NEW.employee_id IS NOT DISTINCT FROM OLD.employee_id
     AND nullif(btrim(NEW.rep_code),'') IS NOT NULL THEN
    RETURN NEW;
  END IF;

  IF NEW.employee_id IS NULL THEN
    RAISE EXCEPTION 'يجب ربط المندوب بموظف حتى يرث كود الموظف';
  END IF;

  SELECT e.employee_code INTO v_employee_code
  FROM public.erp_employees e
  WHERE e.id=NEW.employee_id AND e.company_id=NEW.company_id;

  IF v_employee_code IS NULL THEN
    RAISE EXCEPTION 'الموظف المرتبط بالمندوب غير موجود في الشركة الحالية أو لا يحمل كودًا';
  END IF;

  SELECT c.prefix,c.digits INTO v_employee_prefix,v_employee_digits
  FROM public.erp_code_policy_config(NEW.company_id,'employee','Emp',5) c;

  IF v_employee_prefix IS NULL OR v_employee_prefix !~ '^[A-Za-z]{3}$'
     OR v_employee_digits IS NULL OR v_employee_digits NOT BETWEEN 1 AND 12
     OR left(v_employee_code,length(v_employee_prefix))<>v_employee_prefix THEN
    RAISE EXCEPTION 'كود الموظف لا يطابق سياسة كود الموظفين؛ تعذر توريثه للمندوب';
  END IF;

  v_employee_suffix:=substring(v_employee_code from length(v_employee_prefix)+1);
  IF v_employee_suffix !~ '^[0-9]+$' OR length(v_employee_suffix)<>v_employee_digits THEN
    RAISE EXCEPTION 'الجزء الرقمي من كود الموظف لا يطابق عدد خانات سياسة الموظفين';
  END IF;

  SELECT c.prefix,c.digits INTO v_rep_prefix,v_rep_digits
  FROM public.erp_code_policy_config(NEW.company_id,'delegate','Rep',5) c;

  IF v_rep_prefix IS NULL OR v_rep_prefix !~ '^[A-Za-z]{3}$' THEN
    RAISE EXCEPTION 'بادئة كود المندوب غير صحيحة في سياسات التكويد';
  END IF;

  v_candidate:=v_rep_prefix||v_employee_suffix;

  IF EXISTS (
    SELECT 1 FROM public.erp_sales_representatives r
    WHERE r.company_id=NEW.company_id
      AND r.rep_code=v_candidate
      AND r.id IS DISTINCT FROM NEW.id
  ) THEN
    RAISE EXCEPTION 'كود المندوب الموروث % مستخدم بالفعل لمندوب آخر',v_candidate;
  END IF;

  NEW.rep_code:=v_candidate;
  RETURN NEW;
END;
$function$;

REVOKE ALL ON FUNCTION private.erp_assign_sales_representative_code() FROM PUBLIC,anon,authenticated;

DROP TRIGGER IF EXISTS erp_sales_representatives_central_code ON public.erp_sales_representatives;
CREATE TRIGGER erp_sales_representatives_central_code
BEFORE INSERT OR UPDATE OF employee_id,rep_code
ON public.erp_sales_representatives
FOR EACH ROW
EXECUTE FUNCTION private.erp_assign_sales_representative_code();
