CREATE OR REPLACE FUNCTION public.erp_save_hr_manual_attendance_batch(p_company_id uuid, p_work_date date, p_rows jsonb)
 RETURNS jsonb
 LANGUAGE plpgsql
 SET search_path TO ''
AS $function$
declare
  v_row record;
  v_employee public.erp_employees%rowtype;
  v_existing public.erp_attendance_records%rowtype;
  v_present boolean;
  v_inserted integer := 0;
  v_updated integer := 0;
  v_total integer := 0;
  v_job_id uuid;
  v_check_in timestamptz;
begin
  if auth.uid() is null then
    raise exception 'يلزم تسجيل الدخول' using errcode='28000';
  end if;
  if p_company_id is null or p_work_date is null then
    raise exception 'الشركة وتاريخ كشف الحضور مطلوبان' using errcode='22023';
  end if;
  if p_rows is null or jsonb_typeof(p_rows)<>'array' then
    raise exception 'كشف الحضور يجب أن يكون قائمة' using errcode='22023';
  end if;
  if jsonb_array_length(p_rows)>1000 then
    raise exception 'عدد سجلات كشف الحضور يتجاوز الحد المسموح' using errcode='22023';
  end if;
  if jsonb_array_length(p_rows)=0 then
    return jsonb_build_object('inserted',0,'updated',0,'total',0);
  end if;

  if not public.erp_user_has_company_role(
    p_company_id,array['owner','admin','manager']::text[]
  ) then
    raise exception 'لا تملك صلاحية حفظ كشف الحضور اليدوي' using errcode='42501';
  end if;

  if exists (
    select x.employee_id
    from jsonb_to_recordset(p_rows) as x(
      employee_id uuid,
      job_id uuid,
      attendance_status text,
      attendance_fraction numeric,
      absence_type text,
      absence_penalty_days numeric
    )
    group by x.employee_id
    having count(*)>1
  ) then
    raise exception 'الموظف مكرر في كشف الحضور؛ أرسل كل موظف مرة واحدة' using errcode='23505';
  end if;

  if exists (
    select 1
    from jsonb_to_recordset(p_rows) as x(
      employee_id uuid,
      job_id uuid,
      attendance_status text,
      attendance_fraction numeric,
      absence_type text,
      absence_penalty_days numeric
    )
    where x.employee_id is null
       or x.attendance_status not in ('present','absent','excused')
       or x.attendance_fraction is null
       or x.attendance_fraction<0 or x.attendance_fraction>1
       or coalesce(x.absence_penalty_days,0)<0
       or (x.attendance_status='absent' and (
         nullif(btrim(x.absence_type),'') is null
         or x.absence_type not in (
           'عطلة أسبوعية','إجازة رسمية','إجازة مرضية','إجازة إصابة عمل',
           'إجازة سنوية','غياب بإذن','غياب بدون إذن'
         )
       ))
       or (x.attendance_status='present' and x.attendance_fraction<=0)
       or coalesce(x.absence_penalty_days,0)>5
       or (x.attendance_status<>'absent' and coalesce(x.absence_penalty_days,0)<>0)
       or (x.attendance_status<>'absent' and x.absence_type is not null)
  ) then
    raise exception 'يوجد سجل حضور به حالة أو نسبة أو جزاء غير صالح' using errcode='22023';
  end if;

  if exists (
    select 1
    from jsonb_to_recordset(p_rows) as x(
      employee_id uuid,
      job_id uuid,
      attendance_status text,
      attendance_fraction numeric,
      absence_type text,
      absence_penalty_days numeric
    )
    left join public.erp_hr_jobs j
      on j.id=x.job_id and j.company_id=p_company_id
    where x.job_id is not null and j.id is null
  ) then
    raise exception 'إحدى الوظائف المختارة لا تتبع الشركة المحددة' using errcode='23503';
  end if;

  if exists (
    select 1 from public.erp_payroll_runs r
    where r.company_id=p_company_id
      and r.status in ('approved','posted','paid')
      and r.period_start<=p_work_date
      and r.period_end>=p_work_date
  ) then
    raise exception 'توجد فترة رواتب معتمدة أو مرحلة أو مدفوعة تشمل التاريخ المحدد؛ لا يمكن تعديل الحضور' using errcode='23514';
  end if;

  for v_row in
    select x.employee_id,x.job_id,x.attendance_status,
           x.attendance_fraction,x.absence_type,
           coalesce(x.absence_penalty_days,0) as absence_penalty_days
    from jsonb_to_recordset(p_rows) as x(
      employee_id uuid,
      job_id uuid,
      attendance_status text,
      attendance_fraction numeric,
      absence_type text,
      absence_penalty_days numeric
    )
    order by x.employee_id
  loop
    select e.* into v_employee
    from public.erp_employees e
    where e.id=v_row.employee_id
      and e.company_id=p_company_id
      and e.is_active=true
      and e.employment_status='active'
    for share;
    if not found then
      raise exception 'أحد الموظفين غير نشط أو لا يتبع الشركة المحددة' using errcode='23503';
    end if;

    if not public.erp_user_can_access_employee_scope(p_company_id,v_employee.id) then
      raise exception 'لا تملك صلاحية نطاق أحد الموظفين في كشف الحضور' using errcode='42501';
    end if;

    v_job_id:=coalesce(v_row.job_id,v_employee.job_id);
    if v_job_id is not null and not exists (
      select 1 from public.erp_hr_jobs j
      where j.id=v_job_id and j.company_id=p_company_id
    ) then
      raise exception 'الوظيفة المرتبطة بأحد الموظفين لا تتبع الشركة' using errcode='23503';
    end if;

    perform pg_catalog.pg_advisory_xact_lock(
      pg_catalog.hashtextextended(
        p_company_id::text||':'||v_employee.id::text||':'||p_work_date::text,0
      )
    );

    select a.* into v_existing
    from public.erp_attendance_records a
    where a.company_id=p_company_id
      and a.employee_id=v_employee.id
      and a.work_date=p_work_date
    for update;

    v_present:=v_row.attendance_status='present';

    if found then
      v_check_in:=case
        when v_present then coalesce(
          v_existing.check_in,
          ((p_work_date::timestamp+time '09:00') at time zone 'Africa/Cairo')
        )
        else null
      end;
      update public.erp_attendance_records
      set job_id=v_job_id,
          check_in=v_check_in,
          check_out=v_existing.check_out,
          attendance_status=v_row.attendance_status,
          attendance_fraction=case when v_present then v_row.attendance_fraction else 0 end,
          absence_type=case when v_row.attendance_status='absent' then v_row.absence_type else null end,
          absence_penalty_days=case when v_row.attendance_status='absent' and v_row.absence_type='غياب بدون إذن'
            then v_row.absence_penalty_days else 0 end,
          attendance_source='manual',
          notes=case v_row.attendance_status
            when 'present' then 'تسجيل حضور يدوي'
            when 'absent' then 'حالة غياب: '||coalesce(v_row.absence_type,'')
            else 'لم يسجل حضور'
          end
      where id=v_existing.id and company_id=p_company_id;
      v_updated:=v_updated+1;
    else
      insert into public.erp_attendance_records(
        company_id,employee_id,work_date,job_id,check_in,check_out,
        attendance_status,attendance_fraction,absence_type,absence_penalty_days,
        attendance_source,notes
      )
      values(
        p_company_id,v_employee.id,p_work_date,v_job_id,
        case when v_present then ((p_work_date::timestamp+time '09:00') at time zone 'Africa/Cairo') else null end,
        null,
        v_row.attendance_status,
        case when v_present then v_row.attendance_fraction else 0 end,
        case when v_row.attendance_status='absent' then v_row.absence_type else null end,
        case when v_row.attendance_status='absent' and v_row.absence_type='غياب بدون إذن'
          then v_row.absence_penalty_days else 0 end,
        'manual',
        case v_row.attendance_status
          when 'present' then 'تسجيل حضور يدوي'
          when 'absent' then 'حالة غياب: '||coalesce(v_row.absence_type,'')
          else 'لم يسجل حضور'
        end
      );
      v_inserted:=v_inserted+1;
    end if;
    v_total:=v_total+1;
  end loop;

  return jsonb_build_object('inserted',v_inserted,'updated',v_updated,'total',v_total);
end;
$function$
;

revoke all on function public.erp_save_hr_manual_attendance_batch(uuid,date,jsonb) from public;
revoke all on function public.erp_save_hr_manual_attendance_batch(uuid,date,jsonb) from anon;
grant execute on function public.erp_save_hr_manual_attendance_batch(uuid,date,jsonb) to authenticated;
