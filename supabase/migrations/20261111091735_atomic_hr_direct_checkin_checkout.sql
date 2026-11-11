CREATE OR REPLACE FUNCTION public.erp_record_hr_direct_check_in(p_company_id uuid, p_employee_id uuid, p_notes text DEFAULT NULL::text)
 RETURNS uuid
 LANGUAGE plpgsql
 SET search_path TO ''
AS $function$
declare
  v_employee public.erp_employees%rowtype;
  v_work_date date;
  v_attendance_id uuid;
begin
  if (select auth.uid()) is null then
    raise exception 'يجب تسجيل الدخول أولًا' using errcode='28000';
  end if;
  if p_company_id is null or p_employee_id is null then
    raise exception 'الشركة والموظف مطلوبان' using errcode='22023';
  end if;
  if length(coalesce(p_notes,''))>2000 then
    raise exception 'ملاحظات الحضور تتجاوز الحد المسموح' using errcode='22023';
  end if;
  if not public.erp_user_has_company_role(
    p_company_id,array['owner','admin','manager','operator']::text[]
  ) then
    raise exception 'لا تملك صلاحية تسجيل الحضور المباشر' using errcode='42501';
  end if;

  select e.* into v_employee
  from public.erp_employees e
  where e.id=p_employee_id
    and e.company_id=p_company_id
    and e.is_active=true
    and e.employment_status='active'
  for share;
  if not found then
    raise exception 'الموظف غير نشط أو لا يتبع الشركة المحددة' using errcode='23503';
  end if;
  if not public.erp_user_can_access_employee_scope(p_company_id,p_employee_id) then
    raise exception 'لا تملك صلاحية نطاق الموظف لتسجيل الحضور' using errcode='42501';
  end if;

  v_work_date:=(now() at time zone 'Africa/Cairo')::date;
  if exists (
    select 1 from public.erp_payroll_runs r
    where r.company_id=p_company_id
      and r.status in ('approved','posted','paid')
      and r.period_start<=v_work_date
      and r.period_end>=v_work_date
  ) then
    raise exception 'فترة الرواتب لهذا التاريخ معتمدة أو مرحلة أو مدفوعة؛ لا يمكن تغيير الحضور' using errcode='23514';
  end if;

  perform pg_catalog.pg_advisory_xact_lock(
    pg_catalog.hashtextextended(p_company_id::text||':'||p_employee_id::text||':'||v_work_date::text,0)
  );
  if exists (
    select 1 from public.erp_attendance_records a
    where a.company_id=p_company_id
      and a.employee_id=p_employee_id
      and a.work_date=v_work_date
  ) then
    raise exception 'يوجد سجل حضور لهذا الموظف اليوم؛ لا يستبدل الحضور المباشر سجلًا يدويًا أو بصمة أو حضورًا سابقًا' using errcode='23505';
  end if;

  insert into public.erp_attendance_records(
    company_id,employee_id,work_date,check_in,attendance_status,
    attendance_fraction,absence_type,absence_penalty_days,
    attendance_source,recorded_by,job_id,notes
  )
  values(
    p_company_id,p_employee_id,v_work_date,now(),'present',
    1,null,0,'direct',(select auth.uid()),v_employee.job_id,
    nullif(btrim(coalesce(p_notes,'')),'')
  )
  returning id into v_attendance_id;

  return v_attendance_id;
end;
$function$
;

CREATE OR REPLACE FUNCTION public.erp_record_hr_direct_check_out(p_attendance_id uuid)
 RETURNS uuid
 LANGUAGE plpgsql
 SET search_path TO ''
AS $function$
declare
  v_attendance public.erp_attendance_records%rowtype;
begin
  if (select auth.uid()) is null then
    raise exception 'يجب تسجيل الدخول أولًا' using errcode='28000';
  end if;
  if p_attendance_id is null then
    raise exception 'سجل الحضور مطلوب' using errcode='22023';
  end if;

  select a.* into v_attendance
  from public.erp_attendance_records a
  where a.id=p_attendance_id
  for update;
  if not found then
    raise exception 'سجل الحضور غير موجود' using errcode='P0002';
  end if;
  if not public.erp_user_has_company_role(
    v_attendance.company_id,array['owner','admin','manager']::text[]
  ) then
    raise exception 'تسجيل الانصراف يتطلب صلاحية مدير موارد بشرية أو مدير الشركة' using errcode='42501';
  end if;
  if not public.erp_user_can_access_employee_scope(
    v_attendance.company_id,v_attendance.employee_id
  ) then
    raise exception 'لا تملك صلاحية نطاق الموظف لتسجيل الانصراف' using errcode='42501';
  end if;
  if v_attendance.check_in is null then
    raise exception 'لا يمكن تسجيل انصراف دون وقت حضور مسجل' using errcode='23514';
  end if;
  if v_attendance.check_out is not null then
    raise exception 'تم تسجيل انصراف لهذا السجل بالفعل' using errcode='23514';
  end if;
  if exists (
    select 1 from public.erp_payroll_runs r
    where r.company_id=v_attendance.company_id
      and r.status in ('approved','posted','paid')
      and r.period_start<=v_attendance.work_date
      and r.period_end>=v_attendance.work_date
  ) then
    raise exception 'فترة الرواتب لهذا التاريخ معتمدة أو مرحلة أو مدفوعة؛ لا يمكن تغيير الحضور' using errcode='23514';
  end if;

  update public.erp_attendance_records
  set check_out=now(),updated_at=now()
  where id=p_attendance_id and company_id=v_attendance.company_id
    and check_out is null;
  if not found then
    raise exception 'تغير سجل الحضور أثناء العملية؛ حدّث الشاشة وأعد المحاولة' using errcode='40001';
  end if;

  return p_attendance_id;
end;
$function$
;
revoke all on function public.erp_record_hr_direct_check_in(uuid,uuid,text) from public;
revoke all on function public.erp_record_hr_direct_check_in(uuid,uuid,text) from anon;
grant execute on function public.erp_record_hr_direct_check_in(uuid,uuid,text) to authenticated;

revoke all on function public.erp_record_hr_direct_check_out(uuid) from public;
revoke all on function public.erp_record_hr_direct_check_out(uuid) from anon;
grant execute on function public.erp_record_hr_direct_check_out(uuid) to authenticated;
