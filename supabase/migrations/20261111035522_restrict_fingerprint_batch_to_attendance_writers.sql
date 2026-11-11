CREATE OR REPLACE FUNCTION public.erp_process_hr_fingerprint_batch(p_company_id uuid, p_event_ids uuid[])
 RETURNS jsonb
 LANGUAGE plpgsql
 SET search_path TO ''
AS $function$
declare
  v_bucket record;
  v_employee public.erp_employees%rowtype;
  v_existing public.erp_attendance_records%rowtype;
  v_event_count integer := 0;
  v_group_count integer := 0;
  v_processed integer := 0;
  v_has_attendance boolean;
  v_can_update boolean;
begin
  if auth.uid() is null then
    raise exception 'يلزم تسجيل الدخول' using errcode='28000';
  end if;
  if p_company_id is null or p_event_ids is null then
    raise exception 'الشركة وأحداث البصمة مطلوبة' using errcode='22023';
  end if;
  if cardinality(p_event_ids)>5000 then
    raise exception 'عدد أحداث البصمة في الدفعة يتجاوز الحد المسموح' using errcode='22023';
  end if;
  if cardinality(p_event_ids)=0 then
    return jsonb_build_object('processed_events',0,'processed_groups',0);
  end if;
  if (select count(distinct x) from unnest(p_event_ids) as x)
       <> cardinality(p_event_ids) then
    raise exception 'قائمة أحداث البصمة تحتوي معرفات مكررة' using errcode='23505';
  end if;

  if not public.erp_user_has_company_role(
    p_company_id,array['owner','admin','manager']::text[]
  ) then
    raise exception 'لا تملك صلاحية معالجة أحداث البصمة لهذه الشركة' using errcode='42501';
  end if;

  select count(*) into v_event_count
  from public.erp_hr_attendance_events e
  where e.company_id=p_company_id
    and e.id=any(p_event_ids)
    and e.employee_id is not null
    and e.processing_status<>'processed';

  if v_event_count<>cardinality(p_event_ids) then
    raise exception 'تغيرت مجموعة أحداث البصمة أو أن بعضها عولج بالفعل؛ حدّث الشاشة وأعد المحاولة' using errcode='40001';
  end if;

  v_can_update:=public.erp_user_has_company_role(
    p_company_id,array['owner','admin','manager']::text[]
  );

  for v_bucket in
    select e.employee_id,
           (e.event_at at time zone 'Africa/Cairo')::date as work_date,
           min(e.event_at) as first_event,
           max(e.event_at) as last_event,
           array_agg(e.id order by e.event_at,e.id) as event_ids
    from public.erp_hr_attendance_events e
    where e.company_id=p_company_id
      and e.id=any(p_event_ids)
      and e.employee_id is not null
      and e.processing_status<>'processed'
    group by e.employee_id,(e.event_at at time zone 'Africa/Cairo')::date
    order by work_date,e.employee_id
  loop
    select e.* into v_employee
    from public.erp_employees e
    where e.id=v_bucket.employee_id
      and e.company_id=p_company_id
      and e.is_active=true
      and e.employment_status='active'
    for share;
    if not found then
      raise exception 'أحد الموظفين المرتبطين بالبصمة غير نشط أو لا يتبع الشركة' using errcode='23503';
    end if;

    if not public.erp_user_can_access_employee_scope(p_company_id,v_employee.id) then
      raise exception 'لا تملك صلاحية نطاق هذا الموظف لمعالجة البصمة' using errcode='42501';
    end if;

    if exists (
      select 1 from public.erp_payroll_runs r
      where r.company_id=p_company_id
        and r.status in ('approved','posted','paid')
        and r.period_start<=v_bucket.work_date
        and r.period_end>=v_bucket.work_date
    ) then
      raise exception 'توجد فترة رواتب معتمدة أو مرحلة أو مدفوعة تشمل تاريخ %؛ لا يمكن تعديل الحضور',v_bucket.work_date using errcode='23514';
    end if;

    perform pg_catalog.pg_advisory_xact_lock(
      pg_catalog.hashtextextended(
        p_company_id::text||':'||v_bucket.employee_id::text||':'||v_bucket.work_date::text,0
      )
    );

    select a.* into v_existing
    from public.erp_attendance_records a
    where a.company_id=p_company_id
      and a.employee_id=v_bucket.employee_id
      and a.work_date=v_bucket.work_date
    for update;
    v_has_attendance:=found;

    if v_has_attendance then
      if v_existing.attendance_source<>'fingerprint' then
        raise exception 'يوجد سجل حضور يدوي أو مباشر للموظف بتاريخ %؛ راجعه قبل معالجة البصمة',v_bucket.work_date using errcode='23514';
      end if;
      if not v_can_update then
        raise exception 'تحديث سجل حضور موجود يتطلب دور المالك أو المدير أو مدير الشركة؛ لم تُعالج أحداث البصمة' using errcode='42501';
      end if;

      update public.erp_attendance_records
      set check_in=case
            when check_in is null then v_bucket.first_event
            else least(check_in,v_bucket.first_event)
          end,
          check_out=case
            when v_bucket.last_event>v_bucket.first_event then
              case when check_out is null then v_bucket.last_event
                   else greatest(check_out,v_bucket.last_event) end
            else check_out
          end,
          attendance_status='present',
          attendance_fraction=1,
          absence_type=null,
          absence_penalty_days=0,
          attendance_source='fingerprint',
          notes='معالجة من جهاز البصمة',
          job_id=v_employee.job_id
      where id=v_existing.id and company_id=p_company_id;
    else
      insert into public.erp_attendance_records(
        company_id,employee_id,work_date,check_in,check_out,
        attendance_status,attendance_fraction,absence_type,
        absence_penalty_days,attendance_source,notes,job_id
      )
      values(
        p_company_id,v_employee.id,v_bucket.work_date,
        v_bucket.first_event,
        case when v_bucket.last_event>v_bucket.first_event then v_bucket.last_event else null end,
        'present',1,null,0,'fingerprint','معالجة من جهاز البصمة',v_employee.job_id
      );
    end if;

    update public.erp_hr_attendance_events
    set processing_status='processed',
        processing_note='مطابقة '||coalesce(v_employee.employee_code,'')
    where company_id=p_company_id
      and id=any(v_bucket.event_ids)
      and employee_id=v_employee.id
      and processing_status<>'processed';

    get diagnostics v_processed=row_count;
    if v_processed<>cardinality(v_bucket.event_ids) then
      raise exception 'تعذر وضع كل أحداث البصمة في حالة تمت المعالجة؛ تم التراجع عن الدفعة' using errcode='40001';
    end if;

    v_event_count:=v_event_count+v_processed;
    v_group_count:=v_group_count+1;
  end loop;

  return jsonb_build_object(
    'processed_events',v_event_count,
    'processed_groups',v_group_count
  );
end;
$function$
;

revoke all on function public.erp_process_hr_fingerprint_batch(uuid,uuid[]) from public;
revoke all on function public.erp_process_hr_fingerprint_batch(uuid,uuid[]) from anon;
grant execute on function public.erp_process_hr_fingerprint_batch(uuid,uuid[]) to authenticated;
