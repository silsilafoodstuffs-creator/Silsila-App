create or replace function public.erp_record_construction_stock_movement(
 p_company_id uuid,p_project_id uuid,p_warehouse_id uuid,p_item_id uuid,p_item_name text,
 p_quantity numeric,p_unit text,p_unit_cost numeric,p_movement_date date,p_movement_kind text,p_movement_code text,p_notes text
) returns uuid language plpgsql security invoker set search_path=public,pg_temp
as $$
declare v_movement_id uuid;v_row_id uuid;v_effective_cost numeric(18,4);v_movement_at timestamptz;v_existing public.erp_construction_material_movements%rowtype;
begin
 if auth.uid() is null then raise exception 'يلزم تسجيل الدخول'; end if;
 if p_movement_kind not in ('issue','return') then raise exception 'نوع حركة مواد المشروع غير صالح'; end if;
 if p_movement_code is null or trim(p_movement_code)='' then raise exception 'كود حركة مواد المشروع مطلوب'; end if;
 select * into v_existing from public.erp_construction_material_movements m where m.company_id=p_company_id and m.movement_code=p_movement_code for update;
 if found then
  if v_existing.project_id<>p_project_id or v_existing.item_id<>p_item_id or v_existing.warehouse_id<>p_warehouse_id or v_existing.movement_type<>p_movement_kind or v_existing.quantity<>p_quantity or v_existing.unit<>p_unit or v_existing.movement_date<>p_movement_date then
   raise exception 'كود حركة المواد مستخدم بالفعل ببيانات مختلفة';
  end if;
  return v_existing.id;
 end if;
 if not exists(select 1 from public.erp_construction_projects p where p.id=p_project_id and p.company_id=p_company_id) then raise exception 'المشروع غير موجود في الشركة المحددة'; end if;
 if p_movement_date is null then raise exception 'تاريخ حركة المواد مطلوب'; end if;
 v_movement_at:=case when p_movement_date=current_date then now() else (p_movement_date::timestamp+interval '1 day'-interval '1 microsecond') end;
 v_movement_id:=public.erp_record_inventory_movement(p_company_id,p_warehouse_id,p_item_id,case when p_movement_kind='issue' then 'project_issue' else 'project_return' end,
  p_quantity,p_unit_cost,null,v_movement_at,'construction_project',p_project_id,null,null,p_notes);
 select m.unit_cost into v_effective_cost from public.erp_inventory_movements m where m.id=v_movement_id and m.company_id=p_company_id;
 insert into public.erp_construction_material_movements(company_id,movement_code,project_id,item_id,item_name,warehouse_id,movement_type,quantity,unit,unit_cost,movement_date,inventory_movement_id,notes,created_by)
 values(p_company_id,p_movement_code,p_project_id,p_item_id,p_item_name,p_warehouse_id,p_movement_kind,p_quantity,p_unit,coalesce(v_effective_cost,p_unit_cost),p_movement_date,v_movement_id,p_notes,auth.uid())
 returning id into v_row_id;
 return v_row_id;
end;
$$;
revoke all on function public.erp_record_construction_stock_movement(uuid,uuid,uuid,uuid,text,numeric,text,numeric,date,text,text,text) from public,anon;
grant execute on function public.erp_record_construction_stock_movement(uuid,uuid,uuid,uuid,text,numeric,text,numeric,date,text,text,text) to authenticated;
