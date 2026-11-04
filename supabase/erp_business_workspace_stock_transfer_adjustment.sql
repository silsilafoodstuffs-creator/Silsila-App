create or replace function public.erp_transfer_business_workspace_stock(
 p_workspace_id uuid,p_source_warehouse_id uuid,p_target_warehouse_id uuid,p_item_link_id uuid,p_quantity numeric,p_document_no text,p_movement_date date default current_date,p_notes text default null
) returns uuid language plpgsql security invoker set search_path=pg_catalog,public,auth,private
as $$
declare v_user uuid:=(select auth.uid()); v_source_branch uuid; v_doc uuid; v_available numeric; v_cost numeric;
begin
 if v_user is null then raise exception 'Authentication required' using errcode='28000'; end if;
 if not private.can_access_business_workspace(p_workspace_id,'inventory.manage') then raise exception 'Insufficient inventory permission' using errcode='42501'; end if;
 if p_quantity<=0 or p_source_warehouse_id=p_target_warehouse_id then raise exception 'Invalid transfer quantity or identical warehouses' using errcode='22023'; end if;
 if length(trim(coalesce(p_document_no,'')))>80 then raise exception 'Transfer number is too long' using errcode='22023'; end if;
 select branch_id into v_source_branch from public.erp_business_workspace_warehouses where id=p_source_warehouse_id and workspace_id=p_workspace_id and is_active;
 if v_source_branch is null then raise exception 'Source warehouse is invalid' using errcode='23503'; end if;
 if not exists(select 1 from public.erp_business_workspace_warehouses where id=p_target_warehouse_id and workspace_id=p_workspace_id and is_active) then raise exception 'Target warehouse is invalid' using errcode='23503'; end if;
 if not exists(select 1 from public.erp_business_workspace_item_links where id=p_item_link_id and workspace_id=p_workspace_id and is_enabled) then raise exception 'Item is not enabled in this workspace' using errcode='23503'; end if;
 select coalesce(sum(quantity_in-quantity_out),0),case when coalesce(sum(quantity_in-quantity_out),0)>0 then coalesce(sum(quantity_in*unit_cost-quantity_out*unit_cost),0)/sum(quantity_in-quantity_out) else 0 end
 into v_available,v_cost from public.erp_business_workspace_stock_movements where workspace_id=p_workspace_id and warehouse_id=p_source_warehouse_id and item_link_id=p_item_link_id;
 if v_available<p_quantity then raise exception 'Insufficient source stock: available %, requested %',v_available,p_quantity using errcode='23514'; end if;
 insert into public.erp_business_workspace_documents(workspace_id,branch_id,warehouse_id,document_no,document_type,document_date,notes,status,subtotal,discount,tax,total,created_by)
 values(p_workspace_id,v_source_branch,p_source_warehouse_id,coalesce(nullif(trim(coalesce(p_document_no,'')),''),''),'transfer',coalesce(p_movement_date,current_date),nullif(trim(coalesce(p_notes,'')),''),'draft',p_quantity*v_cost,0,0,p_quantity*v_cost,v_user) returning id into v_doc;
 insert into public.erp_business_workspace_document_lines(workspace_id,document_id,item_link_id,warehouse_id,quantity,unit_price,discount,line_total) values(p_workspace_id,v_doc,p_item_link_id,p_source_warehouse_id,p_quantity,v_cost,0,p_quantity*v_cost);
 insert into public.erp_business_workspace_stock_movements(workspace_id,warehouse_id,item_link_id,document_id,movement_type,quantity_in,quantity_out,unit_cost,movement_date,created_by)
 values(p_workspace_id,p_source_warehouse_id,p_item_link_id,v_doc,'transfer_out',0,p_quantity,v_cost,coalesce(p_movement_date,current_date),v_user),(p_workspace_id,p_target_warehouse_id,p_item_link_id,v_doc,'transfer_in',p_quantity,0,v_cost,coalesce(p_movement_date,current_date),v_user);
 update public.erp_business_workspace_documents set status='posted',posted_by=v_user,posted_at=now(),updated_at=now() where id=v_doc and workspace_id=p_workspace_id and status='draft';
 if private.can_access_business_workspace(p_workspace_id,'audit.write') then insert into public.erp_business_workspace_audit_log(workspace_id,actor_user_id,action,entity_type,entity_id,details) values(p_workspace_id,v_user,'transfer','stock',v_doc::text,jsonb_build_object('source',p_source_warehouse_id,'target',p_target_warehouse_id,'item',p_item_link_id,'quantity',p_quantity)); end if;
 return v_doc;
end $$;
revoke all on function public.erp_transfer_business_workspace_stock(uuid,uuid,uuid,uuid,numeric,text,date,text) from public,anon;
grant execute on function public.erp_transfer_business_workspace_stock(uuid,uuid,uuid,uuid,numeric,text,date,text) to authenticated;

create or replace function public.erp_adjust_business_workspace_stock(
 p_workspace_id uuid,p_warehouse_id uuid,p_item_link_id uuid,p_direction text,p_quantity numeric,p_unit_cost numeric,p_document_no text,p_movement_date date default current_date,p_notes text default null
) returns uuid language plpgsql security invoker set search_path=pg_catalog,public,auth,private
as $$
declare v_user uuid:=(select auth.uid()); v_branch uuid; v_doc uuid; v_available numeric; v_avg_cost numeric; v_in numeric:=0; v_out numeric:=0; v_cost numeric;
begin
 if v_user is null then raise exception 'Authentication required' using errcode='28000'; end if;
 if not private.can_access_business_workspace(p_workspace_id,'inventory.manage') then raise exception 'Insufficient inventory permission' using errcode='42501'; end if;
 if p_direction not in ('increase','decrease') or p_quantity<=0 or coalesce(p_unit_cost,0)<0 then raise exception 'Invalid adjustment values' using errcode='22023'; end if;
 if length(trim(coalesce(p_document_no,'')))>80 then raise exception 'Adjustment number is too long' using errcode='22023'; end if;
 select branch_id into v_branch from public.erp_business_workspace_warehouses where id=p_warehouse_id and workspace_id=p_workspace_id and is_active;
 if v_branch is null then raise exception 'Warehouse is invalid' using errcode='23503'; end if;
 if not exists(select 1 from public.erp_business_workspace_item_links where id=p_item_link_id and workspace_id=p_workspace_id and is_enabled) then raise exception 'Item is not enabled in this workspace' using errcode='23503'; end if;
 select coalesce(sum(quantity_in-quantity_out),0),case when coalesce(sum(quantity_in-quantity_out),0)>0 then coalesce(sum(quantity_in*unit_cost-quantity_out*unit_cost),0)/sum(quantity_in-quantity_out) else 0 end
 into v_available,v_avg_cost from public.erp_business_workspace_stock_movements where workspace_id=p_workspace_id and warehouse_id=p_warehouse_id and item_link_id=p_item_link_id;
 if p_direction='increase' then v_in:=p_quantity; v_cost:=p_unit_cost; else v_out:=p_quantity; v_cost:=v_avg_cost; if v_available<p_quantity then raise exception 'Insufficient stock for decrease: available %, requested %',v_available,p_quantity using errcode='23514'; end if; end if;
 insert into public.erp_business_workspace_documents(workspace_id,branch_id,warehouse_id,document_no,document_type,document_date,notes,status,subtotal,discount,tax,total,created_by)
 values(p_workspace_id,v_branch,p_warehouse_id,coalesce(nullif(trim(coalesce(p_document_no,'')),''),''),'adjustment',coalesce(p_movement_date,current_date),nullif(trim(coalesce(p_notes,'')),''),'draft',p_quantity*v_cost,0,0,p_quantity*v_cost,v_user) returning id into v_doc;
 insert into public.erp_business_workspace_document_lines(workspace_id,document_id,item_link_id,warehouse_id,quantity,unit_price,discount,line_total) values(p_workspace_id,v_doc,p_item_link_id,p_warehouse_id,p_quantity,v_cost,0,p_quantity*v_cost);
 insert into public.erp_business_workspace_stock_movements(workspace_id,warehouse_id,item_link_id,document_id,movement_type,quantity_in,quantity_out,unit_cost,movement_date,created_by)
 values(p_workspace_id,p_warehouse_id,p_item_link_id,v_doc,case when p_direction='increase' then 'adjustment_in' else 'adjustment_out' end,v_in,v_out,v_cost,coalesce(p_movement_date,current_date),v_user);
 update public.erp_business_workspace_documents set status='posted',posted_by=v_user,posted_at=now(),updated_at=now() where id=v_doc and workspace_id=p_workspace_id and status='draft';
 if private.can_access_business_workspace(p_workspace_id,'audit.write') then insert into public.erp_business_workspace_audit_log(workspace_id,actor_user_id,action,entity_type,entity_id,details) values(p_workspace_id,v_user,'adjust','stock',v_doc::text,jsonb_build_object('direction',p_direction,'warehouse',p_warehouse_id,'item',p_item_link_id,'quantity',p_quantity)); end if;
 return v_doc;
end $$;
revoke all on function public.erp_adjust_business_workspace_stock(uuid,uuid,uuid,text,numeric,numeric,text,date,text) from public,anon;
grant execute on function public.erp_adjust_business_workspace_stock(uuid,uuid,uuid,text,numeric,numeric,text,date,text) to authenticated;
