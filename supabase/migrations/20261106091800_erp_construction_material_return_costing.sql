do $$
declare v_definition text;
begin
 v_definition:=pg_get_functiondef('public.erp_record_inventory_movement(uuid,uuid,uuid,text,numeric,numeric,uuid,timestamptz,text,uuid,text,date,text)'::regprocedure);
 v_definition:=replace(v_definition,'if v_kind in (''customer_return'',''project_return'') then','if v_kind=''customer_return'' then');
 if v_definition not like '%if v_kind=''customer_return'' then%' then raise exception 'تعذر تحديث معالجة مرتجع مواد المشروع'; end if;
 execute v_definition;
end $$;

create or replace function public.erp_record_construction_stock_movement(
 p_company_id uuid,p_project_id uuid,p_warehouse_id uuid,p_item_id uuid,p_item_name text,
 p_quantity numeric,p_unit text,p_unit_cost numeric,p_movement_date date,p_movement_kind text,p_movement_code text,p_notes text
) returns uuid language plpgsql security invoker set search_path=public,pg_temp
as $$
declare v_movement_id uuid;v_row_id uuid;v_effective_cost numeric(18,4);v_movement_at timestamptz;v_existing public.erp_construction_material_movements%rowtype;v_project_qty numeric(18,4);v_project_value numeric(18,4);
begin
 if auth.uid() is null then raise exception 'يلزم تسجيل الدخول'; end if;
 if p_movement_kind not in ('issue','return') then raise exception 'نوع حركة مواد المشروع غير صالح'; end if;
 if p_movement_code is null or trim(p_movement_code)='' then raise exception 'كود حركة مواد المشروع مطلوب'; end if;
 select * into v_existing from public.erp_construction_material_movements m where m.company_id=p_company_id and m.movement_code=p_movement_code for update;
 if found then
  if v_existing.project_id<>p_project_id or v_existing.item_id<>p_item_id or v_existing.warehouse_id<>p_warehouse_id or v_existing.movement_type<>p_movement_kind or v_existing.quantity<>p_quantity or v_existing.unit<>p_unit or v_existing.movement_date<>p_movement_date then raise exception 'كود حركة المواد مستخدم بالفعل ببيانات مختلفة'; end if;
  return v_existing.id;
 end if;
 if not exists(select 1 from public.erp_construction_projects p where p.id=p_project_id and p.company_id=p_company_id) then raise exception 'المشروع غير موجود في الشركة المحددة'; end if;
 if p_movement_date is null then raise exception 'تاريخ حركة المواد مطلوب'; end if;
 perform pg_advisory_xact_lock(hashtextextended(p_company_id::text||':'||p_warehouse_id::text||':'||p_item_id::text,0));
 v_movement_at:=case when p_movement_date=current_date then now() else (p_movement_date::timestamp+interval '1 day'-interval '1 microsecond') end;
 if p_movement_kind='return' then
  select coalesce(sum(case when m.movement_type='issue' then m.quantity else -m.quantity end),0),
   coalesce(sum(case when m.movement_type='issue' then m.quantity*m.unit_cost else -m.quantity*m.unit_cost end),0)
  into v_project_qty,v_project_value from public.erp_construction_material_movements m
  where m.company_id=p_company_id and m.project_id=p_project_id and m.item_id=p_item_id and m.warehouse_id=p_warehouse_id and m.movement_date<=p_movement_date;
  if v_project_qty<p_quantity then raise exception 'كمية الإرجاع أكبر من الكمية المصروفة للمشروع. المتاح للإرجاع: %',v_project_qty; end if;
  v_effective_cost:=case when v_project_qty>0 then greatest(v_project_value/v_project_qty,0) else p_unit_cost end;
 else v_effective_cost:=p_unit_cost; end if;
 v_movement_id:=public.erp_record_inventory_movement(p_company_id,p_warehouse_id,p_item_id,case when p_movement_kind='issue' then 'project_issue' else 'project_return' end,
  p_quantity,v_effective_cost,null,v_movement_at,'construction_project',p_project_id,null,null,p_notes);
 select m.unit_cost into v_effective_cost from public.erp_inventory_movements m where m.id=v_movement_id and m.company_id=p_company_id;
 insert into public.erp_construction_material_movements(company_id,movement_code,project_id,item_id,item_name,warehouse_id,movement_type,quantity,unit,unit_cost,movement_date,inventory_movement_id,notes,created_by)
 values(p_company_id,p_movement_code,p_project_id,p_item_id,p_item_name,p_warehouse_id,p_movement_kind,p_quantity,p_unit,coalesce(v_effective_cost,p_unit_cost),p_movement_date,v_movement_id,p_notes,auth.uid())
 returning id into v_row_id;
 return v_row_id;
end;
$$;
revoke all on function public.erp_record_construction_stock_movement(uuid,uuid,uuid,uuid,text,numeric,text,numeric,date,text,text,text) from public,anon;
grant execute on function public.erp_record_construction_stock_movement(uuid,uuid,uuid,uuid,text,numeric,text,numeric,date,text,text,text) to authenticated;
