do $$
declare v_def text;
begin
 v_def:=pg_get_functiondef('public.erp_post_physical_stocktake(uuid,text,uuid)'::regprocedure);
 v_def:=replace(v_def,'v_doc.source<>''stocktake''','v_doc.source not in (''stocktake'',''manual'')');
 if position('v_doc.source not in (''stocktake'',''manual'')' in v_def)=0 then raise exception 'Could not extend stocktake posting source guard'; end if;
 execute v_def;
 v_def:=pg_get_functiondef('public.erp_save_physical_stocktake_counts(uuid,jsonb)'::regprocedure);
 v_def:=replace(v_def,'v_doc.source<>''stocktake''','v_doc.source not in (''stocktake'',''manual'')');
 if position('v_doc.source not in (''stocktake'',''manual'')' in v_def)=0 then raise exception 'Could not extend stocktake save source guard'; end if;
 execute v_def;
end $$;

create or replace function public.erp_create_manual_stock_adjustment(
 p_company_id uuid,p_warehouse_id uuid,p_notes text default null
) returns uuid language plpgsql security definer set search_path='' as $$
declare v_id uuid; v_branch uuid; v_basis text;
begin
 if auth.uid() is null or not public.erp_user_can_access_company(p_company_id) then raise exception 'غير مصرح بإنشاء تسوية لهذه الشركة' using errcode='42501'; end if;
 select branch_id into v_branch from public.erp_warehouses where id=p_warehouse_id and company_id=p_company_id and is_active=true;
 if not found then raise exception 'المخزن غير موجود أو غير نشط'; end if;
 select coalesce((select policy_value from public.erp_program_policies where company_id=p_company_id and policy_key='inventory.stocktake.valuation_basis' and is_enabled=true order by updated_at desc limit 1),'sale') into v_basis;
 insert into public.erp_stocktakes(company_id,branch_id,warehouse_id,source,status,count_mode,valuation_basis,notes,created_by)
 values(p_company_id,v_branch,p_warehouse_id,'manual','draft','default',v_basis,p_notes,auth.uid()) returning id into v_id;
 insert into public.erp_stocktake_lines(stocktake_id,company_id,warehouse_id,item_id,available_snapshot,reserved_snapshot,physical_snapshot,counted_quantity,variance_quantity,unit_id,conversion_factor,valuation_price,valuation_value)
 select v_id,i.company_id,p_warehouse_id,i.id,coalesce(b.quantity_on_hand,0)-coalesce(r.reserved,0),coalesce(r.reserved,0),coalesce(b.quantity_on_hand,0),coalesce(b.quantity_on_hand,0),0,
 coalesce(s.stocktake_unit_id,s.sale_unit_id,s.purchase_unit_id,baseu.id),
 coalesce((select iu.conversion_factor from public.erp_item_units iu where iu.id=coalesce(s.stocktake_unit_id,s.sale_unit_id,s.purchase_unit_id,baseu.id)),1),
 case when v_basis='purchase' then i.purchase_price else i.sale_price end,0
 from public.erp_items i
 left join public.erp_stock_balances b on b.company_id=i.company_id and b.warehouse_id=p_warehouse_id and b.item_id=i.id
 left join lateral (select sum(sr.quantity_base) reserved from public.erp_stock_reservations sr where sr.company_id=i.company_id and sr.warehouse_id=p_warehouse_id and sr.item_id=i.id and sr.status='active') r on true
 left join public.erp_item_warehouse_settings s on s.company_id=i.company_id and s.item_id=i.id and s.warehouse_id=p_warehouse_id
 left join lateral (select iu.id from public.erp_item_units iu where iu.company_id=i.company_id and iu.item_id=i.id and iu.is_active and iu.is_selectable order by iu.conversion_factor asc limit 1) baseu on true
 where i.company_id=p_company_id and i.is_active=true;
 return v_id;
end $$;
revoke all on function public.erp_create_manual_stock_adjustment(uuid,uuid,text) from public,anon;
grant execute on function public.erp_create_manual_stock_adjustment(uuid,uuid,text) to authenticated;