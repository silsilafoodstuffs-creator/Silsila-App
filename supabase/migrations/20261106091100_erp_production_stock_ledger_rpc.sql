-- Route production material issues and finished-goods receipts through the append-only stock ledger RPC.
-- Direct INSERT to erp_inventory_movements is intentionally not granted to authenticated clients.
create or replace function public.erp_record_inventory_movement(
 p_company_id uuid,p_warehouse_id uuid,p_item_id uuid,p_movement_type text,p_quantity numeric,
 p_unit_cost numeric default 0,p_branch_id uuid default null,p_movement_date timestamptz default now(),
 p_reference_type text default null,p_reference_id uuid default null,p_batch_number text default null,
 p_expiry_date date default null,p_notes text default null
) returns uuid
language plpgsql security definer set search_path=public set row_security=off
as $$
declare
 v_id uuid;v_current numeric(18,3);v_warehouse_branch uuid;v_inventory_value numeric(18,4);
 v_effective_cost numeric(14,4):=p_unit_cost;v_in numeric(14,3);v_out numeric(14,3);v_kind text:=lower(trim(p_movement_type));
begin
 if auth.uid() is null then raise exception 'يجب تسجيل الدخول أولًا'; end if;
 if not public.erp_user_has_company_role(p_company_id,array['owner','admin','manager','operator','accountant']::text[]) then raise exception 'ليست لديك صلاحية تسجيل حركة مخزنية لهذه الشركة'; end if;
 if p_company_id is null or p_warehouse_id is null or p_item_id is null then raise exception 'الشركة والمخزن والصنف حقول إلزامية'; end if;
 if p_quantity is null or p_quantity<=0 or p_unit_cost is null or p_unit_cost<0 then raise exception 'الكمية يجب أن تكون أكبر من صفر والتكلفة لا تقل عن صفر'; end if;
 if p_movement_date is null then raise exception 'تاريخ الحركة مطلوب'; end if;
 if p_movement_date>now() then raise exception 'لا يمكن تسجيل حركة مخزنية بتاريخ مستقبلي؛ احتفظ بالمستند مسودة حتى موعده'; end if;
 if v_kind not in ('opening','purchase_receipt','sales_issue','customer_return','supplier_return','transfer_in','transfer_out','adjustment','waste','production_issue','production_receipt') then raise exception 'نوع الحركة المخزنية غير مدعوم'; end if;
 select w.branch_id into v_warehouse_branch from public.erp_warehouses w where w.id=p_warehouse_id and w.company_id=p_company_id and w.is_active;
 if not found then raise exception 'المخزن غير نشط أو لا يتبع الشركة المحددة'; end if;
 if p_branch_id is null then p_branch_id:=v_warehouse_branch; elsif v_warehouse_branch is not null and p_branch_id<>v_warehouse_branch then raise exception 'فرع الحركة يجب أن يطابق فرع المخزن'; end if;
 if not exists(select 1 from public.erp_items i where i.id=p_item_id and i.company_id=p_company_id and i.is_active) then raise exception 'الصنف غير نشط أو لا يتبع الشركة المحددة'; end if;
 if p_branch_id is not null and not exists(select 1 from public.erp_branches b where b.id=p_branch_id and b.company_id=p_company_id and b.is_active) then raise exception 'الفرع غير نشط أو لا يتبع الشركة المحددة'; end if;
 perform pg_advisory_xact_lock(hashtextextended(p_company_id::text||':'||p_warehouse_id::text||':'||p_item_id::text,0));
 v_in:=case when v_kind in ('opening','purchase_receipt','customer_return','transfer_in','production_receipt') then p_quantity else 0 end;
 v_out:=case when v_kind in ('sales_issue','supplier_return','transfer_out','waste','production_issue') then p_quantity else 0 end;
 if v_kind='adjustment' then raise exception 'التسوية تتطلب تحديد اتجاه الزيادة أو النقص؛ استخدم حركة واردة أو منصرفة مناسبة'; end if;
 if v_out>0 and exists(select 1 from public.erp_inventory_movements m where m.company_id=p_company_id and m.warehouse_id=p_warehouse_id and m.item_id=p_item_id and m.movement_date>p_movement_date) then raise exception 'لا يمكن تسجيل صرف بتاريخ أقدم من حركات لاحقة للصنف؛ راجع التسلسل الزمني أولًا'; end if;
 if v_out>0 then
  select coalesce(sum(m.quantity_in-m.quantity_out),0) into v_current from public.erp_inventory_movements m where m.company_id=p_company_id and m.warehouse_id=p_warehouse_id and m.item_id=p_item_id and m.movement_date<=p_movement_date;
  if v_current<p_quantity then raise exception 'الرصيد غير كافٍ. الرصيد الحالي % والكمية المطلوبة %',v_current,p_quantity; end if;
  select coalesce(sum(m.quantity_in*m.unit_cost)-sum(m.quantity_out*m.unit_cost),0) into v_inventory_value from public.erp_inventory_movements m where m.company_id=p_company_id and m.warehouse_id=p_warehouse_id and m.item_id=p_item_id and m.movement_date<=p_movement_date;
  if v_current>0 then v_effective_cost:=greatest(v_inventory_value/v_current,0); end if;
 end if;
 if v_kind='customer_return' then
  select coalesce(sum(m.quantity_in-m.quantity_out),0),coalesce(sum(m.quantity_in*m.unit_cost)-sum(m.quantity_out*m.unit_cost),0) into v_current,v_inventory_value
  from public.erp_inventory_movements m where m.company_id=p_company_id and m.warehouse_id=p_warehouse_id and m.item_id=p_item_id and m.movement_date<=p_movement_date;
  if v_current>0 then v_effective_cost:=greatest(v_inventory_value/v_current,0); else select i.purchase_price into v_effective_cost from public.erp_items i where i.id=p_item_id and i.company_id=p_company_id; end if;
 end if;
 insert into public.erp_inventory_movements(company_id,branch_id,warehouse_id,item_id,movement_date,movement_type,quantity_in,quantity_out,unit_cost,reference_type,reference_id,batch_number,expiry_date,notes,created_by)
 values(p_company_id,p_branch_id,p_warehouse_id,p_item_id,p_movement_date,v_kind,v_in,v_out,v_effective_cost,nullif(trim(p_reference_type),''),p_reference_id,nullif(trim(p_batch_number),''),p_expiry_date,nullif(trim(p_notes),''),auth.uid())
 returning id into v_id;
 return v_id;
end;
$$;
revoke all on function public.erp_record_inventory_movement(uuid,uuid,uuid,text,numeric,numeric,uuid,timestamptz,text,uuid,text,date,text) from public,anon;
grant execute on function public.erp_record_inventory_movement(uuid,uuid,uuid,text,numeric,numeric,uuid,timestamptz,text,uuid,text,date,text) to authenticated;

create or replace function public.erp_record_production_stock_movement(
 p_company_id uuid,p_production_order_id uuid,p_warehouse_id uuid,p_item_id uuid,
 p_item_name text,p_quantity numeric,p_unit text,p_unit_cost numeric,p_movement_date date,
 p_lot_number text,p_movement_kind text
) returns uuid
language plpgsql security invoker set search_path=public,pg_temp
as $$
declare v_movement_id uuid;v_effective_cost numeric(18,4);
begin
 if auth.uid() is null then raise exception 'يلزم تسجيل الدخول'; end if;
 if p_movement_kind not in ('issue','receipt') then raise exception 'نوع حركة إنتاج غير صالح'; end if;
 if p_quantity is null or p_quantity<=0 then raise exception 'الكمية يجب أن تكون أكبر من صفر'; end if;
 if p_unit_cost is null or p_unit_cost<0 then raise exception 'تكلفة الوحدة غير صالحة'; end if;
 if not (public.erp_user_has_company_role(p_company_id,array['owner','admin','manager','operator','accountant'])
  or exists(select 1 from public.erp_company_member_profiles p where p.company_id=p_company_id and p.user_id=(select auth.uid()))) then raise exception 'لا تملك صلاحية على الشركة المحددة'; end if;
 if not exists(select 1 from public.erp_production_orders o where o.id=p_production_order_id and o.company_id=p_company_id) then raise exception 'أمر التصنيع غير موجود في الشركة المحددة'; end if;
 v_movement_id:=public.erp_record_inventory_movement(p_company_id,p_warehouse_id,p_item_id,
  case when p_movement_kind='issue' then 'production_issue' else 'production_receipt' end,
  p_quantity,p_unit_cost,null,p_movement_date::timestamptz,'production_order',p_production_order_id,p_lot_number,null,
  case when p_movement_kind='issue' then 'صرف خامات لأمر تصنيع' else 'استلام إنتاج تام لأمر تصنيع' end);
 select m.unit_cost into v_effective_cost from public.erp_inventory_movements m where m.id=v_movement_id and m.company_id=p_company_id;
 if p_movement_kind='issue' then
  insert into public.erp_production_material_movements(company_id,production_order_id,item_id,item_name,warehouse_id,movement_type,quantity,unit,unit_cost,movement_date,inventory_movement_id,notes,created_by)
  values(p_company_id,p_production_order_id,p_item_id,p_item_name,p_warehouse_id,'issue',p_quantity,p_unit,coalesce(v_effective_cost,p_unit_cost),p_movement_date,v_movement_id,'صرف فعلي من المخزون',auth.uid());
 end if;
 return v_movement_id;
end;
$$;
revoke all on function public.erp_record_production_stock_movement(uuid,uuid,uuid,uuid,text,numeric,text,numeric,date,text,text) from public,anon;
grant execute on function public.erp_record_production_stock_movement(uuid,uuid,uuid,uuid,text,numeric,text,numeric,date,text,text) to authenticated;
