CREATE OR REPLACE FUNCTION public.erp_replace_manufacturing_bom_lines(p_company_id uuid, p_bom_id uuid, p_parent_record_id uuid, p_lines jsonb)
 RETURNS integer
 LANGUAGE plpgsql
 SET search_path TO ''
AS $function$
declare
  v_status text;
  v_parent_details jsonb;
  v_inserted integer := 0;
begin
  if auth.uid() is null then
    raise exception 'يلزم تسجيل الدخول' using errcode = '28000';
  end if;
  if p_company_id is null or p_bom_id is null then
    raise exception 'الشركة وقائمة المواد مطلوبتان' using errcode = '22023';
  end if;
  if p_lines is null or jsonb_typeof(p_lines) <> 'array' then
    raise exception 'مكونات قائمة المواد يجب أن تكون قائمة' using errcode = '22023';
  end if;
  if jsonb_array_length(p_lines) > 1000 then
    raise exception 'عدد مكونات قائمة المواد يتجاوز الحد المسموح' using errcode = '22023';
  end if;

  select b.status into v_status
  from public.erp_manufacturing_boms b
  where b.id=p_bom_id and b.company_id=p_company_id
  for update;
  if not found then
    raise exception 'قائمة المواد غير موجودة في الشركة المحددة' using errcode = 'P0002';
  end if;

  if p_parent_record_id is not null then
    select r.details into v_parent_details
    from public.erp_business_suite_records r
    where r.id=p_parent_record_id
      and r.company_id=p_company_id
      and r.module_key='manufacturing'
      and r.record_type='bom'
    for update;
    if not found then
      raise exception 'السجل العام المرتبط بقائمة المواد غير موجود داخل الشركة' using errcode = 'P0002';
    end if;
    if nullif(v_parent_details->>'_operational_id','') is not null
       and (v_parent_details->>'_operational_id')::uuid<>p_bom_id then
      raise exception 'ارتباط السجل العام بقائمة المواد غير متطابق' using errcode = '23514';
    end if;
  end if;

  if not (
    public.erp_user_has_company_role(p_company_id,array['owner','admin','manager']::text[])
    or exists (
      select 1 from public.erp_company_member_profiles p
      where p.company_id=p_company_id and p.user_id=(select auth.uid())
    )
  ) then
    raise exception 'لا تملك صلاحية تعديل قائمة المواد' using errcode = '42501';
  end if;

  if exists (
    select 1
    from jsonb_to_recordset(p_lines) as x(
      item_id uuid,
      item_name text,
      quantity numeric,
      unit text,
      scrap_percent numeric,
      is_byproduct boolean,
      notes text
    )
    where x.item_id is null
       or nullif(btrim(x.item_name),'') is null
       or nullif(btrim(x.unit),'') is null
       or x.quantity is null or x.quantity<=0
       or coalesce(x.scrap_percent,0)<0
       or coalesce(x.scrap_percent,0)>100
       or x.is_byproduct is null
  ) then
    raise exception 'يوجد مكون بكمية أو وحدة أو نسبة فاقد غير صالحة' using errcode = '22023';
  end if;

  if exists (
    select 1
    from jsonb_to_recordset(p_lines) as x(
      item_id uuid,
      item_name text,
      quantity numeric,
      unit text,
      scrap_percent numeric,
      is_byproduct boolean,
      notes text
    )
    left join public.erp_items i
      on i.id=x.item_id and i.company_id=p_company_id
    where i.id is null or i.item_name is distinct from x.item_name
  ) then
    raise exception 'أحد مكونات قائمة المواد غير موجود أو لا يتبع الشركة المحددة' using errcode = '23503';
  end if;

  delete from public.erp_manufacturing_bom_lines
  where company_id=p_company_id and bom_id=p_bom_id;

  insert into public.erp_manufacturing_bom_lines(
    company_id,bom_id,line_no,item_id,item_name,quantity,unit,scrap_percent,is_byproduct,notes
  )
  select p_company_id,p_bom_id,
         row_number() over (order by x.ordinality)::integer,
         x.item_id,x.item_name,x.quantity,x.unit,
         coalesce(x.scrap_percent,0),x.is_byproduct,x.notes
  from jsonb_to_recordset(p_lines) with ordinality as x(
    item_id uuid,
    item_name text,
    quantity numeric,
    unit text,
    scrap_percent numeric,
    is_byproduct boolean,
    notes text,
    ordinality bigint
  );

  get diagnostics v_inserted=row_count;
  return v_inserted;
end;
$function$


revoke all on function public.erp_replace_manufacturing_bom_lines(uuid,uuid,uuid,jsonb) from public;
revoke all on function public.erp_replace_manufacturing_bom_lines(uuid,uuid,uuid,jsonb) from anon;
grant execute on function public.erp_replace_manufacturing_bom_lines(uuid,uuid,uuid,jsonb) to authenticated;
