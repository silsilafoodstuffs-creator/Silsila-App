create or replace function public.erp_record_production_stock_movement(
 p_company_id uuid,p_production_order_id uuid,p_warehouse_id uuid,p_item_id uuid,
 p_item_name text,p_quantity numeric,p_unit text,p_unit_cost numeric,p_movement_date date,
 p_lot_number text,p_movement_kind text
) returns uuid language plpgsql security invoker set search_path=public,pg_temp
as $$
declare v_movement_id uuid;v_effective_cost numeric(18,4);v_movement_at timestamptz;
begin
 if auth.uid() is null then raise exception 'يلزم تسجيل الدخول'; end if;
 if p_movement_kind not in ('issue','receipt') then raise exception 'نوع حركة إنتاج غير صالح'; end if;
 if p_quantity is null or p_quantity<=0 then raise exception 'الكمية يجب أن تكون أكبر من صفر'; end if;
 if p_unit_cost is null or p_unit_cost<0 then raise exception 'تكلفة الوحدة غير صالحة'; end if;
 if not (public.erp_user_has_company_role(p_company_id,array['owner','admin','manager','operator','accountant'])
  or exists(select 1 from public.erp_company_member_profiles p where p.company_id=p_company_id and p.user_id=(select auth.uid()))) then raise exception 'لا تملك صلاحية على الشركة المحددة'; end if;
 if not exists(select 1 from public.erp_production_orders o where o.id=p_production_order_id and o.company_id=p_company_id) then raise exception 'أمر التصنيع غير موجود في الشركة المحددة'; end if;
 if p_movement_date is null then raise exception 'تاريخ حركة الإنتاج مطلوب'; end if;
 v_movement_at:=case when p_movement_date=current_date then now() else (p_movement_date::timestamp+interval '1 day'-interval '1 microsecond') end;
 v_movement_id:=public.erp_record_inventory_movement(p_company_id,p_warehouse_id,p_item_id,
  case when p_movement_kind='issue' then 'production_issue' else 'production_receipt' end,
  p_quantity,p_unit_cost,null,v_movement_at,'production_order',p_production_order_id,p_lot_number,null,
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
