CREATE OR REPLACE FUNCTION public.erp_sync_production_order_execution(p_company_id uuid, p_production_order_id uuid, p_movement_date date, p_sync_materials boolean, p_materials jsonb, p_produced_quantity numeric, p_actual_hours numeric, p_actual_cost numeric, p_quality jsonb)
 RETURNS jsonb
 LANGUAGE plpgsql
 SET search_path TO ''
AS $function$
declare
  v_order public.erp_production_orders%rowtype;
  v_line record;
  v_branch_id uuid;
  v_received numeric := 0;
  v_target_produced numeric := 0;
  v_material_cost numeric := 0;
  v_work_center_cost numeric := 0;
  v_actual_cost numeric := 0;
  v_issued_count integer := 0;
  v_receipt_delta numeric := 0;
  v_item_name text;
  v_item_unit text;
  v_receipt_cost numeric := 0;
  v_quality_code text;
  v_quality_result text;
  v_inspected numeric := 0;
  v_rejected numeric := 0;
begin
  if auth.uid() is null then
    raise exception 'يلزم تسجيل الدخول' using errcode = '28000';
  end if;
  if p_company_id is null or p_production_order_id is null then
    raise exception 'الشركة وأمر التصنيع مطلوبان' using errcode = '22023';
  end if;
  if p_movement_date is null then
    raise exception 'تاريخ حركة الإنتاج مطلوب' using errcode = '22023';
  end if;
  if p_sync_materials is null or p_materials is null or jsonb_typeof(p_materials)<>'array' then
    raise exception 'تفاصيل خامات الإنتاج يجب أن تكون قائمة' using errcode = '22023';
  end if;
  if jsonb_array_length(p_materials)>500 then
    raise exception 'عدد خامات أمر التصنيع يتجاوز الحد المسموح' using errcode = '22023';
  end if;
  if coalesce(p_produced_quantity,0)<0
     or coalesce(p_actual_hours,0)<0
     or coalesce(p_actual_cost,0)<0 then
    raise exception 'كمية الإنتاج والساعات والتكلفة لا يمكن أن تكون سالبة' using errcode = '22023';
  end if;

  select o.* into v_order
  from public.erp_production_orders o
  where o.id=p_production_order_id and o.company_id=p_company_id
  for update;
  if not found then
    raise exception 'أمر التصنيع غير موجود في الشركة المحددة' using errcode = 'P0002';
  end if;

  if not (
    public.erp_user_has_company_role(
      p_company_id,
      array['owner','admin','manager','operator','accountant']::text[]
    )
    or exists (
      select 1 from public.erp_company_member_profiles p
      where p.company_id=p_company_id and p.user_id=(select auth.uid())
    )
  ) then
    raise exception 'لا تملك صلاحية تنفيذ أمر التصنيع في الشركة المحددة' using errcode = '42501';
  end if;

  if v_order.warehouse_id is null then
    if p_sync_materials and jsonb_array_length(p_materials)>0 then
      raise exception 'حدد مخزن أمر التصنيع قبل صرف الخامات' using errcode = '23514';
    end if;
    if coalesce(p_produced_quantity,0)>0 then
      raise exception 'حدد مخزن أمر التصنيع قبل استلام الإنتاج' using errcode = '23514';
    end if;
  else
    select w.branch_id into v_branch_id
    from public.erp_warehouses w
    where w.id=v_order.warehouse_id and w.company_id=p_company_id;
    if not found or not public.erp_user_can_access_warehouse_scope(p_company_id,v_branch_id,v_order.warehouse_id) then
      raise exception 'لا تملك صلاحية الوصول إلى مخزن أمر التصنيع' using errcode = '42501';
    end if;
  end if;

  if p_sync_materials then
    if exists (
      select 1
      from jsonb_to_recordset(p_materials) as x(
        item_id uuid,item_name text,quantity numeric,unit text,unit_cost numeric
      )
      where x.item_id is null
         or nullif(btrim(x.item_name),'') is null
         or x.quantity is null or x.quantity<=0
         or nullif(btrim(x.unit),'') is null
         or x.unit_cost is null or x.unit_cost<0
    ) then
      raise exception 'يوجد صنف خامة ببيانات أو كمية أو تكلفة غير صالحة' using errcode = '22023';
    end if;

    if exists (
      select item_id
      from jsonb_to_recordset(p_materials) as x(
        item_id uuid,item_name text,quantity numeric,unit text,unit_cost numeric
      )
      group by item_id
      having count(*)>1
    ) then
      raise exception 'يجب دمج تكرار الصنف نفسه في سطر واحد داخل خامات أمر التصنيع' using errcode = '23505';
    end if;

    if exists (
      select 1
      from jsonb_to_recordset(p_materials) as x(
        item_id uuid,item_name text,quantity numeric,unit text,unit_cost numeric
      )
      left join public.erp_items i on i.id=x.item_id and i.company_id=p_company_id
      where i.id is null or i.item_name is distinct from x.item_name
    ) then
      raise exception 'إحدى خامات أمر التصنيع غير موجودة أو لا تتبع الشركة المحددة' using errcode = '23503';
    end if;

    if exists (
      select 1
      from public.erp_production_material_movements m
      where m.company_id=p_company_id
        and m.production_order_id=p_production_order_id
        and m.movement_type='issue'
        and not exists (
          select 1
          from jsonb_to_recordset(p_materials) as x(
            item_id uuid,item_name text,quantity numeric,unit text,unit_cost numeric
          )
          where x.item_id=m.item_id
        )
    ) then
      raise exception 'لا يمكن حذف خامة سبق صرفها من تفاصيل أمر التصنيع؛ سجّل حركة إرجاع معتمدة أولًا' using errcode = '23514';
    end if;

    for v_line in
      select x.item_id,x.item_name,x.quantity,x.unit,x.unit_cost
      from jsonb_to_recordset(p_materials) as x(
        item_id uuid,item_name text,quantity numeric,unit text,unit_cost numeric
      )
      order by x.item_id
    loop
      select coalesce(sum(m.quantity),0)
        into v_received
      from public.erp_production_material_movements m
      where m.company_id=p_company_id
        and m.production_order_id=p_production_order_id
        and m.item_id=v_line.item_id
        and m.movement_type='issue';

      if v_received>v_line.quantity then
        raise exception 'الكمية المسجلة للصنف % أكبر من الكمية المطلوبة في أمر التصنيع',v_line.item_name using errcode = '23514';
      end if;

      if v_line.quantity>v_received then
        perform public.erp_record_production_stock_movement(
          p_company_id,
          p_production_order_id,
          v_order.warehouse_id,
          v_line.item_id,
          v_line.item_name,
          v_line.quantity-v_received,
          v_line.unit,
          v_line.unit_cost,
          p_movement_date,
          v_order.lot_number,
          'issue'
        );
        v_issued_count:=v_issued_count+1;
      end if;
    end loop;
  end if;

  select coalesce(sum(
    m.quantity*m.unit_cost*
    case when m.movement_type='return' then -1 else 1 end
  ),0)
  into v_material_cost
  from public.erp_production_material_movements m
  where m.company_id=p_company_id
    and m.production_order_id=p_production_order_id;

  if v_order.work_center_id is not null then
    select coalesce(w.hourly_cost,0)*coalesce(p_actual_hours,0)
      into v_work_center_cost
    from public.erp_manufacturing_work_centers w
    where w.id=v_order.work_center_id and w.company_id=p_company_id;
    if not found then
      raise exception 'مركز العمل المرتبط بأمر التصنيع غير موجود في الشركة' using errcode = '23503';
    end if;
  end if;

  v_actual_cost:=case
    when coalesce(p_actual_cost,0)>0 then p_actual_cost
    else v_material_cost+v_work_center_cost
  end;

  select coalesce(sum(m.quantity_in),0)
    into v_received
  from public.erp_inventory_movements m
  where m.company_id=p_company_id
    and m.reference_type='production_order'
    and m.reference_id=p_production_order_id
    and m.movement_type='production_receipt';

  if coalesce(p_produced_quantity,0)>0 then
    if p_produced_quantity<v_received then
      raise exception 'لا يمكن تقليل كمية الإنتاج عن الكمية التي تم استلامها بالمخزون بالفعل' using errcode = '23514';
    end if;
    v_target_produced:=p_produced_quantity;
  else
    v_target_produced:=v_received;
  end if;

  v_receipt_delta:=greatest(v_target_produced-v_received,0);

  if v_receipt_delta>0 then
    if v_order.product_id is null or v_order.warehouse_id is null then
      raise exception 'اختر صنف المنتج النهائي والمخزن قبل استلام الإنتاج' using errcode = '23514';
    end if;

    select i.item_name,i.base_unit into v_item_name,v_item_unit
    from public.erp_items i
    where i.id=v_order.product_id and i.company_id=p_company_id;
    if not found then
      raise exception 'المنتج النهائي غير موجود في الشركة المحددة' using errcode = '23503';
    end if;

    v_receipt_cost:=case
      when v_actual_cost>0 then v_actual_cost/nullif(v_target_produced,0)
      else coalesce(v_order.estimated_cost,0)/nullif(coalesce(v_order.planned_quantity,1),0)
    end;

    perform public.erp_record_production_stock_movement(
      p_company_id,
      p_production_order_id,
      v_order.warehouse_id,
      v_order.product_id,
      v_item_name,
      v_receipt_delta,
      v_item_unit,
      v_receipt_cost,
      p_movement_date,
      v_order.lot_number,
      'receipt'
    );
  end if;

  update public.erp_production_orders
  set actual_cost=v_actual_cost,
      actual_hours=coalesce(p_actual_hours,0),
      produced_quantity=v_target_produced,
      updated_at=now()
  where id=p_production_order_id and company_id=p_company_id;

  if p_quality is not null and jsonb_typeof(p_quality)='object' then
    v_quality_code:=nullif(btrim(p_quality->>'inspection_code'),'');
    v_quality_result:=p_quality->>'result';
    v_inspected:=coalesce(nullif(p_quality->>'inspected_quantity','')::numeric,0);
    v_rejected:=coalesce(nullif(p_quality->>'rejected_quantity','')::numeric,0);
    if v_quality_code is null
       or v_quality_result not in ('pass','conditional','fail')
       or v_inspected<0 or v_rejected<0 or v_rejected>v_inspected then
      raise exception 'بيانات فحص الجودة النهائي غير صالحة' using errcode = '22023';
    end if;

    insert into public.erp_production_quality_checks(
      company_id,inspection_code,production_order_id,inspection_stage,
      parameter_name,result,inspected_quantity,rejected_quantity,notes
    ) values (
      p_company_id,v_quality_code,p_production_order_id,
      coalesce(nullif(p_quality->>'inspection_stage',''),'final'),
      coalesce(nullif(p_quality->>'parameter_name',''),'نتيجة الجودة النهائية'),
      v_quality_result,v_inspected,v_rejected,p_quality->>'notes'
    )
    on conflict(company_id,inspection_code) do update
    set production_order_id=excluded.production_order_id,
        inspection_stage=excluded.inspection_stage,
        parameter_name=excluded.parameter_name,
        result=excluded.result,
        inspected_quantity=excluded.inspected_quantity,
        rejected_quantity=excluded.rejected_quantity,
        notes=excluded.notes,
        inspected_at=now();
  end if;

  return jsonb_build_object(
    'issued_items',v_issued_count,
    'received_quantity',v_target_produced,
    'actual_cost',v_actual_cost
  );
end;
$function$


revoke all on function public.erp_sync_production_order_execution(uuid,uuid,date,boolean,jsonb,numeric,numeric,numeric,jsonb) from public;
revoke all on function public.erp_sync_production_order_execution(uuid,uuid,date,boolean,jsonb,numeric,numeric,numeric,jsonb) from anon;
grant execute on function public.erp_sync_production_order_execution(uuid,uuid,date,boolean,jsonb,numeric,numeric,numeric,jsonb) to authenticated;
