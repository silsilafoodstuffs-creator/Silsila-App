CREATE OR REPLACE FUNCTION public.erp_create_physical_stocktake(p_company_id uuid, p_warehouse_id uuid, p_count_mode text DEFAULT 'detailed'::text, p_valuation_basis text DEFAULT NULL::text, p_notes text DEFAULT NULL::text)
 RETURNS uuid
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare v_id uuid; v_branch uuid; v_basis text; v_mode text;
begin
 if auth.uid() is null or not public.erp_user_has_company_role(p_company_id, ARRAY['owner','admin','manager','operator','accountant']::text[]) then raise exception 'غير مصرح بإنشاء جرد لهذه الشركة' using errcode='42501'; end if;
 if p_count_mode not in ('default','detailed') then raise exception 'وضع الجرد غير صحيح'; end if;
 select branch_id into v_branch from public.erp_warehouses where id=p_warehouse_id and company_id=p_company_id and is_active=true;
 if not found then raise exception 'المخزن غير موجود أو غير نشط'; end if;
 if not public.erp_user_can_access_warehouse_scope(p_company_id,v_branch,p_warehouse_id) then
  raise exception 'لا تملك صلاحية الوصول إلى مخزن الجرد أو فرعه' using errcode='42501';
 end if;
 select coalesce((select policy_value from public.erp_program_policies where company_id=p_company_id and policy_key='inventory.stocktake.valuation_basis' and is_enabled=true order by updated_at desc limit 1),'sale') into v_basis;
 if p_valuation_basis is not null then if p_valuation_basis not in ('sale','purchase') then raise exception 'أساس تقييم الجرد غير صحيح'; end if; v_basis:=p_valuation_basis; end if;
 v_mode:=p_count_mode;
 insert into public.erp_stocktakes(company_id,branch_id,warehouse_id,source,status,count_mode,valuation_basis,notes,created_by)
 values(p_company_id,v_branch,p_warehouse_id,'stocktake','draft',v_mode,v_basis,p_notes,auth.uid()) returning id into v_id;
 insert into public.erp_stocktake_lines(stocktake_id,company_id,warehouse_id,item_id,available_snapshot,reserved_snapshot,physical_snapshot,counted_quantity,variance_quantity,unit_id,conversion_factor,valuation_price,valuation_value)
 select v_id,i.company_id,p_warehouse_id,i.id,coalesce(b.quantity_on_hand,0)-coalesce(r.reserved,0),coalesce(r.reserved,0),coalesce(b.quantity_on_hand,0),coalesce(b.quantity_on_hand,0),0,
 case when v_mode='detailed' then baseu.id else coalesce(s.stocktake_unit_id,s.sale_unit_id,s.purchase_unit_id,baseu.id) end,
 case when v_mode='detailed' then coalesce(baseu.conversion_factor,1) else coalesce((select iu.conversion_factor from public.erp_item_units iu where iu.id=coalesce(s.stocktake_unit_id,s.sale_unit_id,s.purchase_unit_id,baseu.id)),1) end,
 case when v_basis='purchase' then i.purchase_price else i.sale_price end,0
 from public.erp_items i
 left join public.erp_stock_balances b on b.company_id=i.company_id and b.warehouse_id=p_warehouse_id and b.item_id=i.id
 left join lateral (select sum(sr.quantity_base) reserved from public.erp_stock_reservations sr where sr.company_id=i.company_id and sr.warehouse_id=p_warehouse_id and sr.item_id=i.id and sr.status='active') r on true
 left join public.erp_item_warehouse_settings s on s.company_id=i.company_id and s.item_id=i.id and s.warehouse_id=p_warehouse_id
 left join lateral (select iu.id,iu.conversion_factor from public.erp_item_units iu where iu.company_id=i.company_id and iu.item_id=i.id and iu.is_active and iu.is_selectable order by iu.conversion_factor asc,iu.is_base_unit desc limit 1) baseu on true
 where i.company_id=p_company_id and i.is_active=true;
 return v_id;
end $function$
;

CREATE OR REPLACE FUNCTION public.erp_create_manual_stock_adjustment(p_company_id uuid, p_warehouse_id uuid, p_notes text DEFAULT NULL::text)
 RETURNS uuid
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare v_id uuid; v_branch uuid; v_basis text;
begin
 if auth.uid() is null or not public.erp_user_has_company_role(p_company_id, ARRAY['owner','admin','manager','operator','accountant']::text[]) then
   raise exception 'غير مصرح بإنشاء تسوية لهذه الشركة' using errcode='42501';
 end if;
 select branch_id into v_branch from public.erp_warehouses
 where id=p_warehouse_id and company_id=p_company_id and is_active=true;
 if not found then raise exception 'المخزن غير موجود أو غير نشط'; end if;
 if not public.erp_user_can_access_warehouse_scope(p_company_id,v_branch,p_warehouse_id) then
   raise exception 'لا تملك صلاحية الوصول إلى مخزن التسوية أو فرعه' using errcode='42501';
 end if;
 select coalesce((select policy_value from public.erp_program_policies
   where company_id=p_company_id and policy_key='inventory.stocktake.valuation_basis'
     and is_enabled=true order by updated_at desc limit 1),'sale') into v_basis;
 insert into public.erp_stocktakes(company_id,branch_id,warehouse_id,source,status,count_mode,valuation_basis,notes,created_by)
 values(p_company_id,v_branch,p_warehouse_id,'manual','draft','default',v_basis,p_notes,auth.uid())
 returning id into v_id;
 insert into public.erp_stocktake_lines(stocktake_id,company_id,warehouse_id,item_id,available_snapshot,reserved_snapshot,
   physical_snapshot,counted_quantity,variance_quantity,unit_id,conversion_factor,valuation_price,valuation_value)
 select v_id,i.company_id,p_warehouse_id,i.id,coalesce(b.quantity_on_hand,0)-coalesce(r.reserved,0),
   coalesce(r.reserved,0),coalesce(b.quantity_on_hand,0),coalesce(b.quantity_on_hand,0),0,
   coalesce(s.stocktake_unit_id,s.sale_unit_id,s.purchase_unit_id,baseu.id),
   coalesce((select iu.conversion_factor from public.erp_item_units iu
      where iu.id=coalesce(s.stocktake_unit_id,s.sale_unit_id,s.purchase_unit_id,baseu.id)),1),
   case when v_basis='purchase' then i.purchase_price else i.sale_price end,0
 from public.erp_items i
 left join public.erp_stock_balances b on b.company_id=i.company_id and b.warehouse_id=p_warehouse_id and b.item_id=i.id
 left join lateral (select sum(sr.quantity_base) reserved from public.erp_stock_reservations sr
   where sr.company_id=i.company_id and sr.warehouse_id=p_warehouse_id and sr.item_id=i.id and sr.status='active') r on true
 left join public.erp_item_warehouse_settings s on s.company_id=i.company_id and s.item_id=i.id and s.warehouse_id=p_warehouse_id
 left join lateral (select iu.id from public.erp_item_units iu where iu.company_id=i.company_id and iu.item_id=i.id
   and iu.is_active and iu.is_selectable order by iu.conversion_factor asc,iu.is_base_unit desc limit 1) baseu on true
 where i.company_id=p_company_id and i.is_active=true;
 return v_id;
end $function$
;

CREATE OR REPLACE FUNCTION public.erp_save_physical_stocktake_counts(p_stocktake_id uuid, p_counts jsonb)
 RETURNS integer
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare v_doc public.erp_stocktakes%rowtype; v_expected integer; v_payload integer; v_updated integer; v_warehouse_branch uuid;
begin
 select * into v_doc from public.erp_stocktakes where id=p_stocktake_id for update;
 if not found then raise exception 'محضر الجرد غير موجود'; end if;
 if auth.uid() is null or not public.erp_user_has_company_role(v_doc.company_id, ARRAY['owner','admin','manager','operator','accountant']::text[]) then
   raise exception 'غير مصرح بحفظ محضر الجرد' using errcode='42501';
 end if;
 if v_doc.source not in ('stocktake','manual') or v_doc.status<>'draft' then raise exception 'لا يمكن تعديل محضر جرد مرحل أو غير فعلي'; end if;
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
 if exists(
  select 1 from public.erp_stocktake_lines l
  where l.stocktake_id=p_stocktake_id
    and (l.company_id<>v_doc.company_id or l.warehouse_id<>v_doc.warehouse_id)
 ) then
  raise exception 'توجد بنود جرد لا تطابق الشركة أو المخزن المرتبط بالمحضر' using errcode='23514';
 end if;
 if jsonb_typeof(p_counts)<>'array' then raise exception 'صيغة كميات الجرد غير صحيحة'; end if;
 select count(*) into v_expected from public.erp_stocktake_lines where stocktake_id=p_stocktake_id;
 select count(distinct x.line_id),count(*) filter(where x.counted_quantity<0)
 into v_payload,v_updated
 from jsonb_to_recordset(p_counts) as x(line_id uuid,counted_quantity numeric);
 if v_payload<>v_expected then raise exception 'قائمة كميات الجرد غير مكتملة أو تحتوي معرفات مكررة'; end if;
 if v_updated>0 then raise exception 'لا يمكن إدخال كمية جرد سالبة'; end if;
 update public.erp_stocktake_lines l set counted_quantity=x.counted_quantity
 from jsonb_to_recordset(p_counts) as x(line_id uuid,counted_quantity numeric)
 where l.id=x.line_id and l.stocktake_id=p_stocktake_id;
 get diagnostics v_updated=row_count;
 if v_updated<>v_expected then raise exception 'بعض بنود الجرد لا تتبع هذا المحضر'; end if;
 return v_updated;
end $function$
;

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


revoke all on function public.erp_create_physical_stocktake(uuid,uuid,text,text,text) from public;
revoke all on function public.erp_create_physical_stocktake(uuid,uuid,text,text,text) from anon;
grant execute on function public.erp_create_physical_stocktake(uuid,uuid,text,text,text) to authenticated;

revoke all on function public.erp_create_manual_stock_adjustment(uuid,uuid,text) from public;
revoke all on function public.erp_create_manual_stock_adjustment(uuid,uuid,text) from anon;
grant execute on function public.erp_create_manual_stock_adjustment(uuid,uuid,text) to authenticated;

revoke all on function public.erp_save_physical_stocktake_counts(uuid,jsonb) from public;
revoke all on function public.erp_save_physical_stocktake_counts(uuid,jsonb) from anon;
grant execute on function public.erp_save_physical_stocktake_counts(uuid,jsonb) to authenticated;

revoke all on function public.erp_post_physical_stocktake(uuid,text,uuid) from public;
revoke all on function public.erp_post_physical_stocktake(uuid,text,uuid) from anon;
grant execute on function public.erp_post_physical_stocktake(uuid,text,uuid) to authenticated;
