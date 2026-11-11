CREATE OR REPLACE FUNCTION public.erp_program_policy_applies(p_company_id uuid, p_policy_key text, p_actor_id uuid)
 RETURNS boolean
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare
  v_enabled boolean;
  v_all boolean;
  v_users jsonb;
  v_erp_user_id uuid;
begin
  if auth.uid() is not null and p_actor_id is distinct from auth.uid() then
    return false;
  end if;

  if auth.uid() is not null and not public.erp_user_can_access_company(p_company_id) then
    return false;
  end if;

  select is_enabled,apply_to_all,user_ids
    into v_enabled,v_all,v_users
  from public.erp_program_policies
  where company_id=p_company_id
    and policy_key=p_policy_key
  limit 1;

  if not found then
    return p_policy_key='skip_quotation';
  end if;
  if not coalesce(v_enabled,false) then
    return false;
  end if;
  if coalesce(v_all,false) then
    return true;
  end if;
  if p_actor_id is null then
    return false;
  end if;

  select u.id into v_erp_user_id
  from public.erp_users u
  where u.company_id=p_company_id
    and u.auth_user_id=p_actor_id
    and u.is_active=true
  limit 1;

  if v_erp_user_id is null then
    return false;
  end if;
  return coalesce(v_users,'[]'::jsonb) ? v_erp_user_id::text;
end;
$function$
;

CREATE OR REPLACE FUNCTION public.erp_enforce_employee_national_id_policy()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
begin
  if new.national_id is not null then
    new.national_id:=btrim(new.national_id);
    if new.national_id !~ '^[0-9]{14}$' then
      raise exception 'الرقم القومي يجب أن يتكون من 14 رقمًا.';
    end if;
    new.national_id_last4:=right(new.national_id,4);
  end if;

  if tg_op='INSERT'
     and public.erp_program_policy_applies(new.company_id,'national_id_required',(select auth.uid()))
     and coalesce(new.national_id,'')='' then
    raise exception 'سياسة البرنامج تشترط تسجيل الرقم القومي المكوّن من 14 رقمًا للموظف الجديد.';
  end if;
  return new;
end;
$function$
;

CREATE OR REPLACE FUNCTION public.erp_create_employee(p_company_id uuid, p_branch_id uuid, p_full_name text, p_national_id text DEFAULT NULL::text, p_phone text DEFAULT NULL::text, p_job_title text DEFAULT NULL::text, p_department_name text DEFAULT NULL::text, p_base_salary numeric DEFAULT 0, p_department_id uuid DEFAULT NULL::uuid, p_job_id uuid DEFAULT NULL::uuid, p_work_location_id uuid DEFAULT NULL::uuid, p_hire_date date DEFAULT NULL::date)
 RETURNS uuid
 LANGUAGE plpgsql
 SET search_path TO ''
AS $function$
declare
  v_branch public.erp_branches%rowtype;
  v_employee_id uuid;
  v_national_id text:=nullif(btrim(coalesce(p_national_id,'')),'');
begin
  if (select auth.uid()) is null then
    raise exception 'يجب تسجيل الدخول أولًا' using errcode='28000';
  end if;
  if p_company_id is null or p_branch_id is null then
    raise exception 'الشركة والفرع مطلوبان لإنشاء الموظف' using errcode='22023';
  end if;
  if nullif(btrim(coalesce(p_full_name,'')),'') is null then
    raise exception 'اسم الموظف مطلوب' using errcode='22023';
  end if;
  if coalesce(p_base_salary,0)<0 then
    raise exception 'الراتب الأساسي لا يمكن أن يكون سالبًا' using errcode='22023';
  end if;
  if length(coalesce(p_full_name,''))>200
     or length(coalesce(p_phone,''))>40
     or length(coalesce(p_job_title,''))>150
     or length(coalesce(p_department_name,''))>150 then
    raise exception 'أحد حقول الموظف يتجاوز الحد المسموح' using errcode='22023';
  end if;
  if v_national_id is not null and v_national_id !~ '^[0-9]{14}$' then
    raise exception 'الرقم القومي يجب أن يتكون من 14 رقمًا' using errcode='22023';
  end if;
  if p_hire_date is not null and p_hire_date>current_date then
    raise exception 'تاريخ التعيين لا يمكن أن يكون مستقبليًا' using errcode='22023';
  end if;

  if not public.erp_user_has_company_role(
    p_company_id,array['owner','admin','manager']::text[]
  ) then
    raise exception 'لا تملك صلاحية إضافة موظف لهذه الشركة' using errcode='42501';
  end if;

  select b.* into v_branch
  from public.erp_branches b
  where b.id=p_branch_id
    and b.company_id=p_company_id
    and b.is_active=true
  for share;
  if not found then
    raise exception 'الفرع غير نشط أو لا يتبع الشركة المحددة' using errcode='23503';
  end if;
  if not public.erp_user_can_access_branch_scope(p_company_id,p_branch_id) then
    raise exception 'لا تملك صلاحية نطاق الفرع لإضافة الموظف' using errcode='42501';
  end if;

  if p_department_id is not null and not exists (
    select 1 from public.erp_hr_departments d
    where d.id=p_department_id
      and d.company_id=p_company_id
      and d.is_active=true
  ) then
    raise exception 'الإدارة المحددة غير نشطة أو لا تتبع الشركة' using errcode='23503';
  end if;

  if p_job_id is not null and not exists (
    select 1 from public.erp_hr_jobs j
    where j.id=p_job_id
      and j.company_id=p_company_id
      and j.is_active=true
      and (j.department_id is null or p_department_id is null or j.department_id=p_department_id)
  ) then
    raise exception 'الوظيفة المحددة غير نشطة أو لا تتبع الإدارة/الشركة' using errcode='23503';
  end if;

  if p_work_location_id is not null and not exists (
    select 1 from public.erp_hr_work_locations l
    where l.id=p_work_location_id
      and l.company_id=p_company_id
      and l.is_active=true
  ) then
    raise exception 'موقع العمل المحدد غير نشط أو لا يتبع الشركة' using errcode='23503';
  end if;

  -- The BEFORE INSERT national-ID trigger remains the final enforcement point
  -- for national_id_required; this call also uses the exact policy key.
  if public.erp_program_policy_applies(p_company_id,'national_id_required',(select auth.uid()))
     and v_national_id is null then
    raise exception 'سياسة البرنامج تشترط تسجيل الرقم القومي المكوّن من 14 رقمًا للموظف الجديد' using errcode='23514';
  end if;

  insert into public.erp_employees(
    company_id,branch_id,employee_code,full_name,national_id,phone,
    job_title,department_name,hire_date,employment_status,base_salary,
    is_active,department_id,job_id,work_location_id
  )
  values(
    p_company_id,p_branch_id,'',btrim(p_full_name),v_national_id,
    nullif(btrim(coalesce(p_phone,'')),''),
    nullif(btrim(coalesce(p_job_title,'')),''),
    nullif(btrim(coalesce(p_department_name,'')),''),
    p_hire_date,'active',coalesce(p_base_salary,0),
    true,p_department_id,p_job_id,p_work_location_id
  )
  returning id into v_employee_id;

  return v_employee_id;
end;
$function$
;
revoke all on function public.erp_program_policy_applies(uuid,text,uuid) from public;
revoke all on function public.erp_program_policy_applies(uuid,text,uuid) from anon;
grant execute on function public.erp_program_policy_applies(uuid,text,uuid) to authenticated;

revoke all on function public.erp_enforce_employee_national_id_policy() from public;
revoke all on function public.erp_enforce_employee_national_id_policy() from anon;

revoke all on function public.erp_create_employee(uuid,uuid,text,text,text,text,text,numeric,uuid,uuid,uuid,date) from public;
revoke all on function public.erp_create_employee(uuid,uuid,text,text,text,text,text,numeric,uuid,uuid,uuid,date) from anon;
grant execute on function public.erp_create_employee(uuid,uuid,text,text,text,text,text,numeric,uuid,uuid,uuid,date) to authenticated;
