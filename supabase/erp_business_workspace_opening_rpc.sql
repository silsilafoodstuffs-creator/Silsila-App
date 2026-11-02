create or replace function public.erp_record_business_workspace_opening(
  p_workspace_id uuid,p_warehouse_id uuid,p_item_link_id uuid,
  p_quantity numeric,p_unit_cost numeric default 0,p_opening_date date default current_date
) returns uuid
language plpgsql security invoker
set search_path=pg_catalog,public,auth,private
as $$
declare v_user uuid := (select auth.uid()); v_opening_id uuid;
begin
 if v_user is null then raise exception 'Authentication required' using errcode='28000'; end if;
 if p_quantity < 0 or p_unit_cost < 0 then raise exception 'Quantity and unit cost must be zero or greater' using errcode='22023'; end if;
 if not private.can_access_business_workspace(p_workspace_id,'inventory.manage') then raise exception 'You do not have permission to manage this workspace inventory' using errcode='42501'; end if;
 if not exists(select 1 from public.erp_business_workspace_warehouses w where w.id=p_warehouse_id and w.workspace_id=p_workspace_id and w.is_active) then raise exception 'Warehouse does not belong to this workspace or is inactive' using errcode='23503'; end if;
 if not exists(select 1 from public.erp_business_workspace_item_links i where i.id=p_item_link_id and i.workspace_id=p_workspace_id and i.is_enabled) then raise exception 'Item is not enabled in this workspace' using errcode='23503'; end if;
 insert into public.erp_business_workspace_stock_openings(workspace_id,warehouse_id,item_link_id,quantity,unit_cost,opening_date,created_by)
 values(p_workspace_id,p_warehouse_id,p_item_link_id,p_quantity,p_unit_cost,coalesce(p_opening_date,current_date),v_user)
 returning id into v_opening_id;
 if p_quantity>0 then
  insert into public.erp_business_workspace_stock_movements(workspace_id,warehouse_id,item_link_id,movement_type,quantity_in,quantity_out,unit_cost,movement_date,created_by)
  values(p_workspace_id,p_warehouse_id,p_item_link_id,'opening',p_quantity,0,p_unit_cost,coalesce(p_opening_date,current_date),v_user);
 end if;
 if private.can_access_business_workspace(p_workspace_id,'audit.write') then
  insert into public.erp_business_workspace_audit_log(workspace_id,actor_user_id,action,entity_type,entity_id,details)
  values(p_workspace_id,v_user,'create','stock_opening',v_opening_id::text,
   jsonb_build_object('warehouse_id',p_warehouse_id,'item_link_id',p_item_link_id,'quantity',p_quantity,'unit_cost',p_unit_cost));
 end if;
 return v_opening_id;
end;
$$;
revoke all on function public.erp_record_business_workspace_opening(uuid,uuid,uuid,numeric,numeric,date) from public,anon;
grant execute on function public.erp_record_business_workspace_opening(uuid,uuid,uuid,numeric,numeric,date) to authenticated;
