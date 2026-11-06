-- Atomic manufacturing material issues and finished-goods receipts.
alter table public.erp_inventory_movements drop constraint if exists erp_inventory_movements_movement_type_check;
alter table public.erp_inventory_movements add constraint erp_inventory_movements_movement_type_check
 check (movement_type = any (array['opening','purchase_receipt','sales_issue','customer_return','supplier_return','transfer_in','transfer_out','adjustment','waste','production_issue','production_receipt']::text[]));

create or replace function public.erp_record_production_stock_movement(
 p_company_id uuid,p_production_order_id uuid,p_warehouse_id uuid,p_item_id uuid,
 p_item_name text,p_quantity numeric,p_unit text,p_unit_cost numeric,p_movement_date date,
 p_lot_number text,p_movement_kind text
) returns uuid
language plpgsql security invoker set search_path=public,pg_temp
as $$
declare v_available numeric(18,4); v_movement_id uuid;
begin
 if auth.uid() is null then raise exception 'يلزم تسجيل الدخول'; end if;
 if p_movement_kind not in ('issue','receipt') then raise exception 'نوع حركة إنتاج غير صالح'; end if;
 if p_quantity is null or p_quantity<=0 then raise exception 'الكمية يجب أن تكون أكبر من صفر'; end if;
 if p_unit_cost is null or p_unit_cost<0 then raise exception 'تكلفة الوحدة غير صالحة'; end if;
 if not (public.erp_user_has_company_role(p_company_id,array['owner','admin','manager','operator'])
   or exists(select 1 from public.erp_company_member_profiles p where p.company_id=p_company_id and p.user_id=(select auth.uid()))) then
   raise exception 'لا تملك صلاحية على الشركة المحددة';
 end if;
 if not exists(select 1 from public.erp_production_orders o where o.id=p_production_order_id and o.company_id=p_company_id) then raise exception 'أمر التصنيع غير موجود في الشركة المحددة'; end if;
 if not exists(select 1 from public.erp_warehouses w where w.id=p_warehouse_id and w.company_id=p_company_id and w.is_active) then raise exception 'المخزن غير موجود أو غير نشط'; end if;
 if not exists(select 1 from public.erp_items i where i.id=p_item_id and i.company_id=p_company_id and i.is_active) then raise exception 'الصنف غير موجود أو غير نشط'; end if;
 perform pg_advisory_xact_lock(hashtextextended(p_company_id::text||':'||p_warehouse_id::text||':'||p_item_id::text,0));
 if p_movement_kind='issue' then
  select coalesce(sum(m.quantity_in-m.quantity_out),0) into v_available from public.erp_inventory_movements m
  where m.company_id=p_company_id and m.warehouse_id=p_warehouse_id and m.item_id=p_item_id
   and m.movement_date <= (p_movement_date::timestamp+interval '1 day'-interval '1 microsecond');
  if v_available<p_quantity then raise exception 'الرصيد غير كافٍ للصنف %. المتاح: %، المطلوب: %',p_item_name,v_available,p_quantity; end if;
 end if;
 insert into public.erp_inventory_movements(company_id,warehouse_id,item_id,movement_date,movement_type,quantity_in,quantity_out,unit_cost,reference_type,reference_id,batch_number,notes,created_by)
 values(p_company_id,p_warehouse_id,p_item_id,p_movement_date::timestamptz,
  case when p_movement_kind='issue' then 'production_issue' else 'production_receipt' end,
  case when p_movement_kind='receipt' then p_quantity else 0 end,
  case when p_movement_kind='issue' then p_quantity else 0 end,
  p_unit_cost,'production_order',p_production_order_id,p_lot_number,
  case when p_movement_kind='issue' then 'صرف خامات لأمر تصنيع' else 'استلام إنتاج تام لأمر تصنيع' end,auth.uid())
 returning id into v_movement_id;
 if p_movement_kind='issue' then
  insert into public.erp_production_material_movements(company_id,production_order_id,item_id,item_name,warehouse_id,movement_type,quantity,unit,unit_cost,movement_date,inventory_movement_id,notes,created_by)
  values(p_company_id,p_production_order_id,p_item_id,p_item_name,p_warehouse_id,'issue',p_quantity,p_unit,p_unit_cost,p_movement_date,v_movement_id,'صرف فعلي من المخزون',auth.uid());
 end if;
 return v_movement_id;
end;
$$;
revoke all on function public.erp_record_production_stock_movement(uuid,uuid,uuid,uuid,text,numeric,text,numeric,date,text,text) from public,anon;
grant execute on function public.erp_record_production_stock_movement(uuid,uuid,uuid,uuid,text,numeric,text,numeric,date,text,text) to authenticated;
