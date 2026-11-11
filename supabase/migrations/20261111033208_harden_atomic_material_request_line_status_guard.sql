create or replace function public.erp_replace_construction_material_request_lines(
  p_company_id uuid,
  p_request_id uuid,
  p_parent_record_id uuid,
  p_lines jsonb
)
returns integer
language plpgsql
security definer
set search_path = ''
set row_security = off
as $function$
declare
  v_project_id uuid;
  v_status text;
  v_created_by uuid;
  v_created_at timestamptz;
  v_parent_status text;
  v_parent_details jsonb;
  v_parent_found boolean := false;
  v_inserted integer := 0;
begin
  if auth.uid() is null then
    raise exception 'يلزم تسجيل الدخول' using errcode = '28000';
  end if;
  if p_company_id is null or p_request_id is null then
    raise exception 'الشركة وطلب المواد مطلوبان' using errcode = '22023';
  end if;
  if p_lines is null or jsonb_typeof(p_lines) <> 'array' then
    raise exception 'تفاصيل طلب المواد يجب أن تكون قائمة' using errcode = '22023';
  end if;
  if jsonb_array_length(p_lines) > 500 then
    raise exception 'عدد بنود طلب المواد يتجاوز الحد المسموح' using errcode = '22023';
  end if;

  select r.project_id,r.status,r.created_by,r.created_at
    into v_project_id,v_status,v_created_by,v_created_at
  from public.erp_construction_material_requests r
  where r.id=p_request_id and r.company_id=p_company_id
  for update;
  if not found then
    raise exception 'طلب المواد غير موجود في الشركة المحددة' using errcode = 'P0002';
  end if;

  if p_parent_record_id is not null then
    select b.status,b.details into v_parent_status,v_parent_details
    from public.erp_business_suite_records b
    where b.id=p_parent_record_id and b.company_id=p_company_id
      and b.module_key='contracting' and b.record_type='material_request'
    for update;
    v_parent_found:=found;
    if not v_parent_found then
      raise exception 'السجل العام المرتبط بطلب المواد غير موجود داخل الشركة' using errcode = 'P0002';
    end if;
    if nullif(v_parent_details->>'_operational_id','') is not null
       and (v_parent_details->>'_operational_id')::uuid<>p_request_id then
      raise exception 'ارتباط السجل العام بطلب المواد غير متطابق' using errcode = '23514';
    end if;
  else
    select b.status,b.details into v_parent_status,v_parent_details
    from public.erp_business_suite_records b
    where b.company_id=p_company_id
      and b.module_key='contracting' and b.record_type='material_request'
      and b.record_code=(
        select r.request_code from public.erp_construction_material_requests r
        where r.id=p_request_id and r.company_id=p_company_id
      )
    for update;
    v_parent_found:=found;
  end if;

  if v_parent_found and v_parent_status=any(array['approved','fulfilled']) then
    raise exception 'طلب المواد المعتمد أو المنفذ لا يمكن تغيير بنوده' using errcode = '23514';
  end if;
  if v_status='fulfilled' then
    raise exception 'طلب المواد المنفذ لا يمكن تغيير بنوده' using errcode = '23514';
  end if;
  if v_status='approved' and not v_parent_found then
    if v_created_by is distinct from (select auth.uid())
       or v_created_at < now()-interval '5 minutes'
       or exists (
         select 1 from public.erp_construction_material_request_lines l
         where l.company_id=p_company_id and l.request_id=p_request_id
       ) then
      raise exception 'طلب المواد المعتمد لا يمكن تغيير بنوده بعد إنشائه' using errcode = '23514';
    end if;
  end if;

  if not (
    public.erp_user_has_company_role(p_company_id,array['owner','admin','manager']::text[])
    or exists (
      select 1 from public.erp_company_member_profiles p
      where p.company_id=p_company_id and p.user_id=(select auth.uid())
    )
  ) then
    raise exception 'لا تملك صلاحية تعديل بنود طلب المواد' using errcode = '42501';
  end if;
  if not public.erp_user_can_access_project_scope(p_company_id,v_project_id) then
    raise exception 'لا تملك صلاحية الوصول إلى المشروع المرتبط بطلب المواد' using errcode = '42501';
  end if;

  if exists (
    select 1 from jsonb_to_recordset(p_lines) as x(
      item_id uuid,item_code text,item_name text,quantity numeric,
      unit text,approved_quantity numeric,notes text
    )
    where x.item_id is null
       or nullif(btrim(x.item_name),'') is null
       or nullif(btrim(x.unit),'') is null
       or x.quantity is null or x.quantity<=0
       or coalesce(x.approved_quantity,0)<0
       or coalesce(x.approved_quantity,0)>x.quantity
  ) then
    raise exception 'يوجد بند ببيانات غير صالحة أو كمية معتمدة أكبر من المطلوبة' using errcode = '22023';
  end if;
  if exists (
    select 1 from jsonb_to_recordset(p_lines) as x(
      item_id uuid,item_code text,item_name text,quantity numeric,
      unit text,approved_quantity numeric,notes text
    )
    left join public.erp_items i on i.id=x.item_id and i.company_id=p_company_id
    where i.id is null or i.item_code is distinct from x.item_code
       or i.item_name is distinct from x.item_name
  ) then
    raise exception 'أحد أصناف الطلب غير موجود أو لا يتبع الشركة المحددة' using errcode = '23503';
  end if;

  delete from public.erp_construction_material_request_lines
  where company_id=p_company_id and request_id=p_request_id;
  insert into public.erp_construction_material_request_lines(
    company_id,request_id,item_id,item_code,item_name,quantity,unit,approved_quantity,notes
  )
  select p_company_id,p_request_id,x.item_id,x.item_code,x.item_name,x.quantity,x.unit,
         coalesce(x.approved_quantity,0),x.notes
  from jsonb_to_recordset(p_lines) as x(
    item_id uuid,item_code text,item_name text,quantity numeric,
    unit text,approved_quantity numeric,notes text
  );
  get diagnostics v_inserted=row_count;
  return v_inserted;
end;
$function$;

revoke all on function public.erp_replace_construction_material_request_lines(uuid,uuid,uuid,jsonb) from public;
revoke all on function public.erp_replace_construction_material_request_lines(uuid,uuid,uuid,jsonb) from anon;
grant execute on function public.erp_replace_construction_material_request_lines(uuid,uuid,uuid,jsonb) to authenticated;
