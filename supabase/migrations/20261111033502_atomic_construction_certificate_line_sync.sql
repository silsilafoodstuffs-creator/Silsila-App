CREATE OR REPLACE FUNCTION public.erp_sync_construction_certificate_lines(p_company_id uuid, p_certificate_id uuid, p_parent_record_id uuid, p_lines jsonb, p_replace_lines boolean)
 RETURNS integer
 LANGUAGE plpgsql
 SET search_path TO ''
AS $function$
declare
  v_project_id uuid;
  v_status text;
  v_gross_amount numeric;
  v_created_by uuid;
  v_created_at timestamptz;
  v_parent_status text;
  v_parent_details jsonb;
  v_parent_found boolean := false;
  v_line_amount numeric := 0;
  v_inserted integer := 0;
  v_certified numeric := 0;
  v_paid numeric := 0;
begin
  if auth.uid() is null then
    raise exception 'يلزم تسجيل الدخول' using errcode = '28000';
  end if;
  if p_company_id is null or p_certificate_id is null then
    raise exception 'الشركة والمستخلص مطلوبان' using errcode = '22023';
  end if;
  if p_lines is null or jsonb_typeof(p_lines) <> 'array' then
    raise exception 'بنود المستخلص يجب أن تكون قائمة' using errcode = '22023';
  end if;
  if jsonb_array_length(p_lines) > 1000 then
    raise exception 'عدد بنود المستخلص يتجاوز الحد المسموح' using errcode = '22023';
  end if;

  select c.project_id,c.status,c.gross_amount,c.created_by,c.created_at
    into v_project_id,v_status,v_gross_amount,v_created_by,v_created_at
  from public.erp_construction_payment_certificates c
  where c.id=p_certificate_id and c.company_id=p_company_id
  for update;
  if not found then
    raise exception 'المستخلص غير موجود في الشركة المحددة' using errcode = 'P0002';
  end if;

  if p_parent_record_id is not null then
    select b.status,b.details into v_parent_status,v_parent_details
    from public.erp_business_suite_records b
    where b.id=p_parent_record_id and b.company_id=p_company_id
      and b.module_key='contracting' and b.record_type='certificate'
    for update;
    v_parent_found:=found;
    if not v_parent_found then
      raise exception 'السجل العام المرتبط بالمستخلص غير موجود داخل الشركة' using errcode = 'P0002';
    end if;
    if nullif(v_parent_details->>'_operational_id','') is not null
       and (v_parent_details->>'_operational_id')::uuid<>p_certificate_id then
      raise exception 'ارتباط السجل العام بالمستخلص غير متطابق' using errcode = '23514';
    end if;
  else
    select b.status,b.details into v_parent_status,v_parent_details
    from public.erp_business_suite_records b
    where b.company_id=p_company_id
      and b.module_key='contracting' and b.record_type='certificate'
      and b.record_code=(
        select c.certificate_number from public.erp_construction_payment_certificates c
        where c.id=p_certificate_id and c.company_id=p_company_id
      )
    for update;
    v_parent_found:=found;
  end if;

  if v_parent_found and v_parent_status=any(array['approved','paid']) then
    raise exception 'المستخلص المعتمد أو المدفوع لا يمكن تعديل بنوده' using errcode = '23514';
  end if;
  if v_status='paid' and not v_parent_found then
    if v_created_by is distinct from (select auth.uid())
       or v_created_at < now()-interval '5 minutes'
       or exists (
         select 1 from public.erp_construction_certificate_lines l
         where l.company_id=p_company_id and l.certificate_id=p_certificate_id
       ) then
      raise exception 'المستخلص المعتمد أو المدفوع لا يمكن تعديل بنوده بعد إنشائه' using errcode = '23514';
    end if;
  end if;

  if not (
    public.erp_user_has_company_role(p_company_id,array['owner','admin','manager']::text[])
    or exists (
      select 1 from public.erp_company_member_profiles p
      where p.company_id=p_company_id and p.user_id=(select auth.uid())
    )
  ) then
    raise exception 'لا تملك صلاحية إدارة بنود المستخلص' using errcode = '42501';
  end if;
  if not public.erp_user_can_access_project_scope(p_company_id,v_project_id) then
    raise exception 'لا تملك صلاحية الوصول إلى مشروع المستخلص' using errcode = '42501';
  end if;

  if p_replace_lines then
    if exists (
      select 1 from jsonb_to_recordset(p_lines) as x(
        boq_line_id uuid,current_quantity numeric,cumulative_quantity numeric,unit_rate numeric
      )
      where x.boq_line_id is null
         or x.current_quantity is null or x.current_quantity<=0
         or x.cumulative_quantity is null
         or x.unit_rate is null or x.unit_rate<0
    ) then
      raise exception 'يوجد بند مستخلص بكمية أو سعر غير صالح' using errcode = '22023';
    end if;
    if exists (
      select x.boq_line_id from jsonb_to_recordset(p_lines) as x(
        boq_line_id uuid,current_quantity numeric,cumulative_quantity numeric,unit_rate numeric
      )
      group by x.boq_line_id having count(*)>1
    ) then
      raise exception 'لا يمكن تكرار بند المقايسة مرتين في المستخلص نفسه' using errcode = '23505';
    end if;
    if exists (
      select 1
      from jsonb_to_recordset(p_lines) as x(
        boq_line_id uuid,current_quantity numeric,cumulative_quantity numeric,unit_rate numeric
      )
      left join public.erp_construction_boq_lines b
        on b.id=x.boq_line_id and b.company_id=p_company_id and b.project_id=v_project_id
      where b.id is null
         or x.cumulative_quantity<b.approved_quantity
         or x.cumulative_quantity>b.planned_quantity
         or abs((x.cumulative_quantity-b.approved_quantity)-x.current_quantity)>0.0001
    ) then
      raise exception 'كميات المستخلص لا تطابق الكمية المعتمدة السابقة أو كمية المقايسة' using errcode = '23514';
    end if;

    select coalesce(sum(round(x.current_quantity*x.unit_rate,3)),0)
      into v_line_amount
    from jsonb_to_recordset(p_lines) as x(
      boq_line_id uuid,current_quantity numeric,cumulative_quantity numeric,unit_rate numeric
    );
    if abs(round(v_line_amount,3)-round(v_gross_amount,3))>0.001 then
      raise exception 'إجمالي بنود المستخلص لا يطابق إجمالي المستخلص' using errcode = '23514';
    end if;

    delete from public.erp_construction_certificate_lines
    where company_id=p_company_id and certificate_id=p_certificate_id;
    insert into public.erp_construction_certificate_lines(
      company_id,certificate_id,boq_line_id,current_quantity,cumulative_quantity,unit_rate,amount
    )
    select p_company_id,p_certificate_id,x.boq_line_id,x.current_quantity,
           x.cumulative_quantity,x.unit_rate,round(x.current_quantity*x.unit_rate,3)
    from jsonb_to_recordset(p_lines) as x(
      boq_line_id uuid,current_quantity numeric,cumulative_quantity numeric,unit_rate numeric
    );
    get diagnostics v_inserted=row_count;
  end if;

  if v_status=any(array['approved','paid']) then
    update public.erp_construction_boq_lines b
    set approved_quantity=l.cumulative_quantity
    from public.erp_construction_certificate_lines l
    where l.company_id=p_company_id and l.certificate_id=p_certificate_id
      and b.id=l.boq_line_id and b.company_id=p_company_id and b.project_id=v_project_id;

    update public.erp_construction_payment_certificates
    set approved_at=coalesce(approved_at,now()),
        paid_at=case when v_status='paid' then coalesce(paid_at,now()) else paid_at end
    where id=p_certificate_id and company_id=p_company_id;
  end if;

  select
    coalesce(sum(case when c.status in ('approved','paid') then c.net_amount else 0 end),0),
    coalesce(sum(case when c.status='paid' then c.net_amount else 0 end),0)
  into v_certified,v_paid
  from public.erp_construction_payment_certificates c
  where c.company_id=p_company_id and c.project_id=v_project_id;

  update public.erp_construction_projects
  set certified_amount=v_certified,paid_amount=v_paid,updated_at=now()
  where id=v_project_id and company_id=p_company_id;

  return v_inserted;
end;
$function$


revoke all on function public.erp_sync_construction_certificate_lines(uuid,uuid,uuid,jsonb,boolean) from public;
revoke all on function public.erp_sync_construction_certificate_lines(uuid,uuid,uuid,jsonb,boolean) from anon;
grant execute on function public.erp_sync_construction_certificate_lines(uuid,uuid,uuid,jsonb,boolean) to authenticated;
