create or replace function public.erp_post_physical_stocktake(
 p_stocktake_id uuid,p_target_type text default null,p_target_id uuid default null
) returns jsonb
language plpgsql security definer set search_path=''
as $$
declare v_doc public.erp_stocktakes%rowtype; v_total numeric(18,2); v_shortage numeric(18,2);
begin
 select * into v_doc from public.erp_stocktakes where id=p_stocktake_id for update;
 if not found then raise exception 'محضر الجرد غير موجود'; end if;
 if auth.uid() is null or not public.erp_user_can_access_company(v_doc.company_id) then
   raise exception 'غير مصرح بترحيل محضر الجرد' using errcode='42501';
 end if;
 if v_doc.status<>'draft' or v_doc.source<>'stocktake' then raise exception 'المحضر ليس مسودة جرد فعلية قابلة للترحيل'; end if;
 if exists(select 1 from public.erp_stocktake_lines where stocktake_id=p_stocktake_id and counted_quantity<0) then
   raise exception 'لا يمكن ترحيل كمية جرد سالبة';
 end if;
 update public.erp_stocktake_lines
 set variance_quantity=counted_quantity-physical_snapshot,
     valuation_value=round(abs(counted_quantity-physical_snapshot)*valuation_price,2)
 where stocktake_id=p_stocktake_id;
 select coalesce(sum(valuation_value),0),
        coalesce(sum(case when variance_quantity<0 then valuation_value else 0 end),0)
 into v_total,v_shortage
 from public.erp_stocktake_lines where stocktake_id=p_stocktake_id;
 if v_shortage>0 then
   if p_target_type not in ('employee','expense') or p_target_id is null then
     raise exception 'يجب تحديد الموظف أو بند الصرف لتوجيه قيمة العجز';
   end if;
   if p_target_type='employee' and not exists(select 1 from public.erp_employees where id=p_target_id and company_id=v_doc.company_id and is_active=true) then
     raise exception 'الموظف المحدد غير موجود أو غير نشط';
   end if;
   if p_target_type='expense' and not exists(select 1 from public.erp_stocktake_expense_items where id=p_target_id and company_id=v_doc.company_id and is_active=true) then
     raise exception 'بند الصرف المحدد غير موجود أو غير نشط';
   end if;
 end if;
 insert into public.erp_stock_adjustment_lines(stocktake_id,company_id,item_id,increase_quantity,shortage_quantity,unit_cost,valuation_value)
 select p_stocktake_id,v_doc.company_id,l.item_id,greatest(l.variance_quantity,0),greatest(-l.variance_quantity,0),
        coalesce(b.average_unit_cost,case when v_doc.valuation_basis='purchase' then i.purchase_price else i.sale_price end,0),l.valuation_value
 from public.erp_stocktake_lines l join public.erp_items i on i.id=l.item_id and i.company_id=l.company_id
 left join public.erp_stock_balances b on b.company_id=l.company_id and b.warehouse_id=l.warehouse_id and b.item_id=l.item_id
 where l.stocktake_id=p_stocktake_id and l.variance_quantity<>0
 on conflict(stocktake_id,item_id) do update set increase_quantity=excluded.increase_quantity,
 shortage_quantity=excluded.shortage_quantity,unit_cost=excluded.unit_cost,valuation_value=excluded.valuation_value;
 insert into public.erp_inventory_movements(company_id,branch_id,warehouse_id,item_id,movement_date,movement_type,quantity_in,quantity_out,unit_cost,reference_type,reference_id,notes,created_by)
 select v_doc.company_id,v_doc.branch_id,v_doc.warehouse_id,l.item_id,now(),'adjustment',
        greatest(l.variance_quantity,0),greatest(-l.variance_quantity,0),
        coalesce(b.average_unit_cost,case when v_doc.valuation_basis='purchase' then i.purchase_price else i.sale_price end,0),
        'stocktake',p_stocktake_id,'ترحيل جرد فعلي',auth.uid()
 from public.erp_stocktake_lines l join public.erp_items i on i.id=l.item_id and i.company_id=l.company_id
 left join public.erp_stock_balances b on b.company_id=l.company_id and b.warehouse_id=l.warehouse_id and b.item_id=l.item_id
 where l.stocktake_id=p_stocktake_id and l.variance_quantity<>0;
 if v_shortage>0 then
   insert into public.erp_stocktake_settlements(company_id,stocktake_id,target_type,target_id,amount)
   values(v_doc.company_id,p_stocktake_id,p_target_type,p_target_id,v_shortage);
   update public.erp_stocktakes set settlement_target_type=p_target_type,settlement_target_id=p_target_id where id=p_stocktake_id;
 end if;
 update public.erp_stocktakes set status='posted',posted_at=now() where id=p_stocktake_id;
 return jsonb_build_object('stocktake_id',p_stocktake_id,'status','posted','valuation_total',v_total,'shortage_value',v_shortage);
end $$;