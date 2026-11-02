create or replace function private.get_workspace_silsila_stock(p_workspace_id uuid,p_item_link_id uuid default null)
returns table(item_link_id uuid,platform_item_id uuid,item_code text,item_name text,base_unit text,workspace_quantity numeric,reorder_level numeric,central_on_hand numeric,central_reserved numeric,central_available numeric)
language plpgsql stable security definer set search_path=pg_catalog,public,auth,private
as $$
declare v_user uuid:=(select auth.uid()); v_company uuid;
begin
 if v_user is null or not private.can_access_business_workspace(p_workspace_id,'inventory.read') or not private.can_access_business_workspace(p_workspace_id,'items.read') then raise exception 'Insufficient permission to compare workspace stock with Silsila' using errcode='42501'; end if;
 select platform_company_id into v_company from public.erp_business_workspaces where id=p_workspace_id and is_active;
 if v_company is null then raise exception 'The workspace is not linked to a Silsila company catalog' using errcode='22023'; end if;
 return query
 with links as (
  select l.id,l.platform_item_id,l.reorder_level,ci.item_code,ci.item_name,ci.base_unit
  from public.erp_business_workspace_item_links l join public.erp_items ci on ci.id=l.platform_item_id and ci.company_id=v_company and ci.is_active
  where l.workspace_id=p_workspace_id and l.is_enabled and (p_item_link_id is null or l.id=p_item_link_id)
 ), own_stock as (
  select sm.item_link_id,sum(sm.quantity_in-sm.quantity_out)::numeric as qty
  from public.erp_business_workspace_stock_movements sm join public.erp_business_workspace_warehouses wh on wh.id=sm.warehouse_id and wh.workspace_id=sm.workspace_id and wh.is_active
  where sm.workspace_id=p_workspace_id and private.can_access_business_workspace_location(p_workspace_id,wh.branch_id,wh.id)
  group by sm.item_link_id
 ), central_stock as (
  select m.item_id,coalesce(sum(m.quantity_in-m.quantity_out),0)::numeric as on_hand
  from public.erp_inventory_movements m join public.erp_warehouses wh on wh.id=m.warehouse_id and wh.company_id=v_company and wh.is_active
  where m.company_id=v_company group by m.item_id
 ), reserved as (
  select r.item_id,coalesce(sum(r.quantity_base),0)::numeric as qty from public.erp_stock_reservations r where r.company_id=v_company and r.status='active' group by r.item_id
 )
 select l.id,l.platform_item_id,l.item_code,l.item_name,l.base_unit,coalesce(o.qty,0),coalesce(l.reorder_level,0),
  coalesce(c.on_hand,0),coalesce(r.qty,0),greatest(coalesce(c.on_hand,0)-coalesce(r.qty,0),0)
 from links l left join own_stock o on o.item_link_id=l.id left join central_stock c on c.item_id=l.platform_item_id left join reserved r on r.item_id=l.platform_item_id
 order by l.item_name;
end $$;
revoke all on function private.get_workspace_silsila_stock(uuid,uuid) from public,anon;
grant execute on function private.get_workspace_silsila_stock(uuid,uuid) to authenticated;
create or replace function public.erp_get_workspace_silsila_stock(p_workspace_id uuid,p_item_link_id uuid default null)
returns table(item_link_id uuid,platform_item_id uuid,item_code text,item_name text,base_unit text,workspace_quantity numeric,reorder_level numeric,central_on_hand numeric,central_reserved numeric,central_available numeric)
language sql security invoker set search_path=pg_catalog,public,auth,private
as $$ select * from private.get_workspace_silsila_stock(p_workspace_id,p_item_link_id); $$;
revoke all on function public.erp_get_workspace_silsila_stock(uuid,uuid) from public,anon;
grant execute on function public.erp_get_workspace_silsila_stock(uuid,uuid) to authenticated;
