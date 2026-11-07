begin;
create or replace function public.erp_hr_validate_staffing_plan()
returns trigger
language plpgsql
security definer
set search_path = ''
set row_security = 'off'
as $function$
begin
  if not exists (
    select 1 from public.erp_hr_jobs j
    where j.id = new.job_id and j.company_id = new.company_id
  ) then
    raise exception 'الوظيفة المحددة لا تتبع الشركة الحالية.';
  end if;

  if new.work_location_id is not null and not exists (
    select 1 from public.erp_hr_work_locations w
    where w.id = new.work_location_id and w.company_id = new.company_id
  ) then
    raise exception 'موقع العمل المحدد لا يتبع الشركة الحالية.';
  end if;

  if new.status = 'approved' then
    if not public.erp_user_has_company_role(new.company_id, array['owner','admin']) then
      raise exception 'اعتماد خطة الملاك الوظيفي متاح لمالك الشركة أو مدير النظام فقط.';
    end if;
    new.approved_by := auth.uid();
    new.approved_at := now();

    if exists (
      select 1
      from public.erp_hr_staffing_plans p
      where p.company_id = new.company_id
        and p.job_id = new.job_id
        and (
          p.work_location_id is null
          or new.work_location_id is null
          or p.work_location_id = new.work_location_id
        )
        and p.status = 'approved'
        and p.id is distinct from new.id
        and daterange(p.effective_from, coalesce(p.effective_to + 1, 'infinity'::date), '[)')
            && daterange(new.effective_from, coalesce(new.effective_to + 1, 'infinity'::date), '[)')
    ) then
      raise exception 'توجد خطة ملاك معتمدة متداخلة لنفس الوظيفة أو لنطاق موقع يشملها.';
    end if;
  else
    new.approved_by := null;
    new.approved_at := null;
  end if;

  new.updated_at := now();
  return new;
end;
$function$;
commit;
