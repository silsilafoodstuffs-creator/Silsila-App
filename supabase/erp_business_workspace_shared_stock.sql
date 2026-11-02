create or replace function private.get_shared_business_workspace_stock(p_company_id uuid,p_item_id uuid)
returns table(workspace_id uuid,workspace_name text,account_kind text,activity_type text,branch_name text,warehouse_name text,item_id uuid,item_code text,item_name text,shared_quantity numeric,reorder_level numeric,central_on_hand numeric,central_reserved numeric,central_available numeric)
language plpgsql stable security definer set search_path=pg_catalog,public,auth,private
as $$
begin
 if (select auth.uid()) is null or not private.can_review_business_workspace_item_proposals() then raise exception 'Only active Silsila management users can view shared activity stock' using errcode='42501'; end if;
 if p_company_id is null or p_item_id is null then raise exception 'Company and item are required' using errcode='22023'; end if;
 if not exists(select 1 from public.erp_items i where i.id=p_item_id and i.company_id=p_company_id and i.is_active) then raise exception 'Item is not active in the selected company' using errcode='23503'; end if;
 return query
 with central as (
  select coalesce(sum(m.quantity_in-m.quantity_out),0)::numeric as on_hand
  from public.erp_inventory_movements m join public.erp_warehouses cw on cw.id=m.warehouse_id and cw.company_id=p_company_id and cw.is_active
  where m.company_id=p_company_id and m.item_id=p_item_id
 ), reserved as (
  select coalesce(sum(r.quantity_base),0)::numeric as quantity from public.erp_stock_reservations r
  where r.company_id=p_company_id and r.item_id=p_item_id and r.status='active'
 )
 select w.id,w.workspace_name,w.account_kind,w.activity_type,b.name_ar,wh.name_ar,i.id,ci.item_code,ci.item_name,
  coalesce(sum(sm.quantity_in-sm.quantity_out),0)::numeric,i.reorder_level,central.on_hand,reserved.quantity,greatest(central.on_hand-reserved.quantity,0)::numeric
 from public.erp_business_workspace_item_links i
 join public.erp_business_workspaces w on w.id=i.workspace_id and w.is_active
 join public.erp_business_workspace_warehouses wh on wh.workspace_id=w.id and wh.is_active and wh.show_balance_in_silsila
 join public.erp_business_workspace_branches b on b.id=wh.branch_id and b.workspace_id=w.id and b.is_active
 join public.erp_items ci on ci.id=i.platform_item_id and ci.company_id=p_company_id and ci.id=p_item_id and ci.is_active
 left join public.erp_business_workspace_stock_movements sm on sm.workspace_id=w.id and sm.warehouse_id=wh.id and sm.item_link_id=i.id
 cross join central cross join reserved
 where i.is_enabled
 group by w.id,w.workspace_name,w.account_kind,w.activity_type,b.name_ar,wh.name_ar,i.id,ci.item_code,ci.item_name,i.reorder_level,central.on_hand,reserved.quantity
 order by w.workspace_name,b.name_ar,wh.name_ar;
end $$;
revoke all on function private.get_shared_business_workspace_stock(uuid,uuid) from public,anon;
grant execute on function private.get_shared_business_workspace_stock(uuid,uuid) to authenticated;
create or replace function public.erp_get_shared_business_workspace_stock(p_company_id uuid,p_item_id uuid)
returns table(workspace_id uuid,workspace_name text,account_kind text,activity_type text,branch_name text,warehouse_name text,item_id uuid,item_code text,item_name text,shared_quantity numeric,reorder_level numeric,central_on_hand numeric,central_reserved numeric,central_available numeric)
language sql security invoker set search_path=pg_catalog,public,auth,private
as $$ select * from private.get_shared_business_workspace_stock(p_company_id,p_item_id); $$;
revoke all on function public.erp_get_shared_business_workspace_stock(uuid,uuid) from public,anon;
grant execute on function public.erp_get_shared_business_workspace_stock(uuid,uuid) to authenticated;
