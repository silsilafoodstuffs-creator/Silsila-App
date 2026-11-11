CREATE OR REPLACE FUNCTION public.erp_post_physical_stocktake(p_stocktake_id uuid, p_target_type text DEFAULT NULL::text, p_target_id uuid DEFAULT NULL::uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare v_doc public.erp_stocktakes%rowtype; v_total numeric(18,2); v_shortage numeric(18,2); v_line record; v_current numeric(18,3); v_warehouse_branch uuid; v_target_employee_branch uuid;
begin
 select * into v_doc from public.erp_stocktakes where id=p_stocktake_id for update;
 if not found then raise exception 'محضر التسوية غير موجود'; end if;
 if auth.uid() is null or not public.erp_user_has_company_role(v_doc.company_id, ARRAY['owner','admin','manager','operator','accountant']::text[]) then raise exception 'غير مصرح بترحيل التسوية' using errcode='42501'; end if;
 if v_doc.status<>'draft' or v_doc.source not in ('stocktake','manual') then raise exception 'المستند ليس مسودة قابلة للترحيل'; end if;
 select w.branch_id into v_warehouse_branch
 from public.erp_warehouses w
 where w.id=v_doc.warehouse_id and w.company_id=v_doc.company_id and w.is_active;
 if not found then raise exception 'مخزن محضر الجرد غير نشط أو لا يتبع الشركة'; end if;
 if v_doc.branch_id is not null and v_doc.branch_id<>v_warehouse_branch then
  raise exception 'فرع محضر الجرد لا يطابق فرع المخزن';
 end if;
 if not public.erp_user_can_access_warehouse_scope(v_doc.company_id,v_warehouse_branch,v_doc.warehouse_id) then
  raise exception 'لا تملك صلاحية الوصول إلى مخزن محضر الجرد أو فرعه' using errcode='42501';
 end if;
 v_doc.branch_id:=coalesce(v_doc.branch_id,v_warehouse_branch);
 if v_doc.branch_id=v_warehouse_branch then
  update public.erp_stocktakes set branch_id=v_warehouse_branch
  where id=p_stocktake_id and company_id=v_doc.company_id and branch_id is null;
 end if;
 if exists(
  select 1 from public.erp_stocktake_lines l
  where l.stocktake_id=p_stocktake_id
    and (l.company_id<>v_doc.company_id or l.warehouse_id<>v_doc.warehouse_id)
 ) then
  raise exception 'توجد بنود جرد لا تطابق الشركة أو المخزن المرتبط بالمحضر' using errcode='23514';
 end if;
 if exists(select 1 from public.erp_stocktake_lines where stocktake_id=p_stocktake_id and counted_quantity<0) then raise exception 'لا يمكن ترحيل كمية سالبة'; end if;
 for v_line in select item_id,warehouse_id,physical_snapshot from public.erp_stocktake_lines where stocktake_id=p_stocktake_id order by warehouse_id,item_id for update loop
   perform pg_advisory_xact_lock(hashtextextended(v_doc.company_id::text||':'||v_line.warehouse_id::text||':'||v_line.item_id::text,0));
   select coalesce(sum(m.quantity_in-m.quantity_out),0)::numeric(18,3) into v_current from public.erp_inventory_movements m
   where m.company_id=v_doc.company_id and m.warehouse_id=v_line.warehouse_id and m.item_id=v_line.item_id and m.movement_date<=now();
   if round(v_current,3)<>round(v_line.physical_snapshot,3) then raise exception 'تغير رصيد صنف بعد إنشاء لقطة التسوية؛ حدّث التسوية وأعد المراجعة قبل الترحيل'; end if;
 end loop;
 update public.erp_stocktake_lines set variance_quantity=counted_quantity-physical_snapshot,valuation_value=round(abs(counted_quantity-physical_snapshot)*valuation_price,2) where stocktake_id=p_stocktake_id;
 select coalesce(sum(valuation_value),0),coalesce(sum(case when variance_quantity<0 then valuation_value else 0 end),0) into v_total,v_shortage from public.erp_stocktake_lines where stocktake_id=p_stocktake_id;
 if v_shortage>0 then
   if p_target_type not in ('employee','expense') or p_target_id is null then raise exception 'يجب تحديد الموظف أو بند الصرف لتوجيه قيمة العجز'; end if;
   if p_target_type='employee' then
     select e.branch_id into v_target_employee_branch
     from public.erp_employees e
     where e.id=p_target_id and e.company_id=v_doc.company_id
       and e.is_active=true and e.employment_status='active';
     if not found then raise exception 'الموظف المحدد غير موجود أو غير نشط'; end if;
     if not public.erp_user_can_access_employee_scope(v_doc.company_id,p_target_id) then
       raise exception 'لا تملك صلاحية نطاق الموظف المختار لتوجيه عجز الجرد' using errcode='42501';
     end if;
   end if;
   if p_target_type='expense' and not exists(select 1 from public.erp_stocktake_expense_items where id=p_target_id and company_id=v_doc.company_id and is_active=true) then raise exception 'بند الصرف المحدد غير موجود أو غير نشط'; end if;
 end if;
 insert into public.erp_stock_adjustment_lines(stocktake_id,company_id,item_id,increase_quantity,shortage_quantity,unit_cost,valuation_value)
 select p_stocktake_id,v_doc.company_id,l.item_id,greatest(l.variance_quantity,0),greatest(-l.variance_quantity,0),coalesce(b.average_unit_cost,case when v_doc.valuation_basis='purchase' then i.purchase_price else i.sale_price end,0),l.valuation_value
 from public.erp_stocktake_lines l join public.erp_items i on i.id=l.item_id and i.company_id=l.company_id
 left join public.erp_stock_balances b on b.company_id=l.company_id and b.warehouse_id=l.warehouse_id and b.item_id=l.item_id
 where l.stocktake_id=p_stocktake_id and l.variance_quantity<>0
 on conflict(stocktake_id,item_id) do update set increase_quantity=excluded.increase_quantity,shortage_quantity=excluded.shortage_quantity,unit_cost=excluded.unit_cost,valuation_value=excluded.valuation_value;
 insert into public.erp_inventory_movements(company_id,branch_id,warehouse_id,item_id,movement_date,movement_type,quantity_in,quantity_out,unit_cost,reference_type,reference_id,notes,created_by)
 select v_doc.company_id,v_doc.branch_id,v_doc.warehouse_id,l.item_id,now(),'adjustment',greatest(l.variance_quantity,0),greatest(-l.variance_quantity,0),
 coalesce(b.average_unit_cost,case when v_doc.valuation_basis='purchase' then i.purchase_price else i.sale_price end,0),
 case when v_doc.source='manual' then 'manual_adjustment' else 'stocktake' end,p_stocktake_id,
 case when v_doc.source='manual' then 'ترحيل تسوية مخزنية يدوية' else 'ترحيل جرد فعلي' end,auth.uid()
 from public.erp_stocktake_lines l join public.erp_items i on i.id=l.item_id and i.company_id=l.company_id
 left join public.erp_stock_balances b on b.company_id=l.company_id and b.warehouse_id=l.warehouse_id and b.item_id=l.item_id
 where l.stocktake_id=p_stocktake_id and l.variance_quantity<>0;
 if v_shortage>0 then
   insert into public.erp_stocktake_settlements(company_id,stocktake_id,target_type,target_id,amount) values(v_doc.company_id,p_stocktake_id,p_target_type,p_target_id,v_shortage);
   update public.erp_stocktakes set settlement_target_type=p_target_type,settlement_target_id=p_target_id where id=p_stocktake_id;
 end if;
 update public.erp_stocktakes set status='posted',posted_at=now() where id=p_stocktake_id;
 return jsonb_build_object('stocktake_id',p_stocktake_id,'source',v_doc.source,'status','posted','valuation_total',v_total,'shortage_value',v_shortage);
end $function$
;

revoke all on function public.erp_post_physical_stocktake(uuid,text,uuid) from public;
revoke all on function public.erp_post_physical_stocktake(uuid,text,uuid) from anon;
grant execute on function public.erp_post_physical_stocktake(uuid,text,uuid) to authenticated;
