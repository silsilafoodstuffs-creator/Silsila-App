CREATE OR REPLACE FUNCTION public.erp_replace_construction_material_request_lines(p_company_id uuid, p_request_id uuid, p_parent_record_id uuid, p_lines jsonb)
 RETURNS integer
 LANGUAGE plpgsql
 SET search_path TO ''
AS $function$
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

if exists (
    select 1 from public.erp_construction_material_request_lines
    where company_id=p_company_id and request_id=p_request_id
  ) and not public.erp_user_has_company_role(p_company_id,array['owner','admin']::text[]) then
    raise exception 'تعديل أو استبدال بنود الطلب الموجودة يتطلب دور المالك أو المدير الإداري؛ يمكن إضافة البنود عند إنشاء الطلب لأول مرة.' using errcode='42501';
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
$function$
;

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
  if v_status=any(array['approved','paid']) and not v_parent_found then
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

if exists (
    select 1 from public.erp_construction_certificate_lines
    where company_id=p_company_id and certificate_id=p_certificate_id
  ) and not public.erp_user_has_company_role(p_company_id,array['owner','admin']::text[]) then
    raise exception 'استبدال بنود مستخلص موجود يتطلب دور المالك أو المدير الإداري؛ لا يسمح دور مدير الشركة بحذف البنود.' using errcode='42501';
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
;

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

if exists (
    select 1 from public.erp_manufacturing_bom_lines
    where company_id=p_company_id and bom_id=p_bom_id
  ) and not public.erp_user_has_company_role(p_company_id,array['owner','admin']::text[]) then
    raise exception 'استبدال مكونات قائمة مواد موجودة يتطلب دور المالك أو المدير الإداري؛ لا يسمح دور مدير الشركة بحذف المكونات.' using errcode='42501';
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
;

revoke all on function public.erp_replace_construction_material_request_lines(uuid,uuid,uuid,jsonb) from public;
revoke all on function public.erp_replace_construction_material_request_lines(uuid,uuid,uuid,jsonb) from anon;
grant execute on function public.erp_replace_construction_material_request_lines(uuid,uuid,uuid,jsonb) to authenticated;

revoke all on function public.erp_sync_construction_certificate_lines(uuid,uuid,uuid,jsonb,boolean) from public;
revoke all on function public.erp_sync_construction_certificate_lines(uuid,uuid,uuid,jsonb,boolean) from anon;
grant execute on function public.erp_sync_construction_certificate_lines(uuid,uuid,uuid,jsonb,boolean) to authenticated;

revoke all on function public.erp_replace_manufacturing_bom_lines(uuid,uuid,uuid,jsonb) from public;
revoke all on function public.erp_replace_manufacturing_bom_lines(uuid,uuid,uuid,jsonb) from anon;
grant execute on function public.erp_replace_manufacturing_bom_lines(uuid,uuid,uuid,jsonb) to authenticated;
