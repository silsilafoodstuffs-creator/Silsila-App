create or replace function public.erp_create_business_workspace_document(
 p_workspace_id uuid,p_branch_id uuid,p_warehouse_id uuid,p_document_no text,p_document_type text,
 p_document_date date,p_counterparty_name text,p_notes text,p_lines jsonb,p_tax numeric default 0
) returns uuid language plpgsql security invoker set search_path=pg_catalog,public,auth,private
as $$
declare v_user uuid := (select auth.uid()); v_permission text; v_doc_id uuid;
 v_subtotal numeric:=0; v_discount numeric:=0; v_total numeric:=0; v_line jsonb;
 v_item_id uuid; v_line_wh uuid; v_qty numeric; v_price numeric; v_disc numeric; v_line_total numeric;
begin
 if v_user is null then raise exception 'Authentication required' using errcode='28000'; end if;
 if p_document_type not in ('purchase','purchase_return','sale','sale_return') then raise exception 'Unsupported document type' using errcode='22023'; end if;
 v_permission:=case when p_document_type in ('purchase','purchase_return') then 'purchases.manage' else 'sales.manage' end;
 if not private.can_access_business_workspace(p_workspace_id,v_permission) then raise exception 'Insufficient permission to create this document' using errcode='42501'; end if;
 if length(trim(coalesce(p_document_no,''))) not between 2 and 80 then raise exception 'Document number is required' using errcode='22023'; end if;
 if p_tax<0 then raise exception 'Tax cannot be negative' using errcode='22023'; end if;
 if jsonb_typeof(p_lines)<>'array' or jsonb_array_length(p_lines)=0 then raise exception 'At least one document line is required' using errcode='22023'; end if;
 if not exists(select 1 from public.erp_business_workspace_branches b where b.id=p_branch_id and b.workspace_id=p_workspace_id and b.is_active) then raise exception 'Branch is invalid for this workspace' using errcode='23503'; end if;
 if not exists(select 1 from public.erp_business_workspace_warehouses w where w.id=p_warehouse_id and w.workspace_id=p_workspace_id and w.is_active) then raise exception 'Warehouse is invalid for this workspace' using errcode='23503'; end if;
 insert into public.erp_business_workspace_documents(workspace_id,branch_id,warehouse_id,document_no,document_type,document_date,counterparty_name,notes,status,subtotal,discount,tax,total,created_by)
 values(p_workspace_id,p_branch_id,p_warehouse_id,trim(p_document_no),p_document_type,coalesce(p_document_date,current_date),nullif(trim(coalesce(p_counterparty_name,'')),''),nullif(trim(coalesce(p_notes,'')),''),'draft',0,0,p_tax,p_tax,v_user)
 returning id into v_doc_id;
 for v_line in select value from jsonb_array_elements(p_lines) loop
  v_item_id:=(v_line->>'item_link_id')::uuid;
  v_line_wh:=coalesce(nullif(v_line->>'warehouse_id','')::uuid,p_warehouse_id);
  v_qty:=(v_line->>'quantity')::numeric;
  v_price:=coalesce((v_line->>'unit_price')::numeric,0);
  v_disc:=coalesce((v_line->>'discount')::numeric,0);
  if v_qty<=0 or v_price<0 or v_disc<0 or v_disc>v_qty*v_price then raise exception 'Invalid quantity, price, or discount in document line' using errcode='22023'; end if;
  if not exists(select 1 from public.erp_business_workspace_item_links i where i.id=v_item_id and i.workspace_id=p_workspace_id and i.is_enabled) then raise exception 'Document line contains an inactive or foreign workspace item' using errcode='23503'; end if;
  if not exists(select 1 from public.erp_business_workspace_warehouses w where w.id=v_line_wh and w.workspace_id=p_workspace_id and w.is_active) then raise exception 'Document line warehouse is invalid' using errcode='23503'; end if;
  v_line_total:=(v_qty*v_price)-v_disc; v_subtotal:=v_subtotal+(v_qty*v_price); v_discount:=v_discount+v_disc;
  insert into public.erp_business_workspace_document_lines(workspace_id,document_id,item_link_id,warehouse_id,quantity,unit_price,discount,line_total)
  values(p_workspace_id,v_doc_id,v_item_id,v_line_wh,v_qty,v_price,v_disc,v_line_total);
 end loop;
 v_total:=v_subtotal-v_discount+p_tax;
 update public.erp_business_workspace_documents set subtotal=v_subtotal,discount=v_discount,tax=p_tax,total=v_total,updated_at=now() where id=v_doc_id and workspace_id=p_workspace_id;
 if private.can_access_business_workspace(p_workspace_id,'audit.write') then
  insert into public.erp_business_workspace_audit_log(workspace_id,actor_user_id,action,entity_type,entity_id,details)
  values(p_workspace_id,v_user,'create','document',v_doc_id::text,jsonb_build_object('document_no',p_document_no,'document_type',p_document_type,'total',v_total,'line_count',jsonb_array_length(p_lines)));
 end if;
 return v_doc_id;
end $$;
revoke all on function public.erp_create_business_workspace_document(uuid,uuid,uuid,text,text,date,text,text,jsonb,numeric) from public,anon;
grant execute on function public.erp_create_business_workspace_document(uuid,uuid,uuid,text,text,date,text,text,jsonb,numeric) to authenticated;

create or replace function public.erp_post_business_workspace_document(p_document_id uuid)
returns boolean language plpgsql security invoker set search_path=pg_catalog,public,auth,private
as $$
declare v_user uuid:=(select auth.uid()); v_doc public.erp_business_workspace_documents%rowtype;
 v_permission text; v_line record; v_available numeric; v_avg_cost numeric; v_in numeric; v_out numeric;
begin
 if v_user is null then raise exception 'Authentication required' using errcode='28000'; end if;
 select * into v_doc from public.erp_business_workspace_documents where id=p_document_id for update;
 if not found then raise exception 'Document not found or not accessible' using errcode='P0002'; end if;
 if v_doc.status<>'approved' then raise exception 'Only approved documents can be posted' using errcode='22023'; end if;
 if v_doc.document_type not in ('purchase','purchase_return','sale','sale_return') then raise exception 'This document type requires a dedicated posting workflow' using errcode='22023'; end if;
 v_permission:=case when v_doc.document_type in ('purchase','purchase_return') then 'purchases.manage' else 'sales.manage' end;
 if not private.can_access_business_workspace(v_doc.workspace_id,v_permission) then raise exception 'Insufficient permission to post this document' using errcode='42501'; end if;
 if not exists(select 1 from public.erp_business_workspace_document_lines l where l.document_id=v_doc.id and l.workspace_id=v_doc.workspace_id) then raise exception 'Cannot post an empty document' using errcode='22023'; end if;
 for v_line in select l.* from public.erp_business_workspace_document_lines l where l.document_id=v_doc.id and l.workspace_id=v_doc.workspace_id order by l.created_at loop
  select coalesce(sum(m.quantity_in-m.quantity_out),0),
   case when coalesce(sum(m.quantity_in-m.quantity_out),0)>0 then coalesce(sum(m.quantity_in*m.unit_cost-m.quantity_out*m.unit_cost),0)/sum(m.quantity_in-m.quantity_out) else 0 end
  into v_available,v_avg_cost from public.erp_business_workspace_stock_movements m
  where m.workspace_id=v_doc.workspace_id and m.warehouse_id=v_line.warehouse_id and m.item_link_id=v_line.item_link_id;
  v_in:=0; v_out:=0;
  if v_doc.document_type='purchase' then v_in:=v_line.quantity; v_avg_cost:=v_line.unit_price;
  elsif v_doc.document_type='purchase_return' then v_out:=v_line.quantity; if v_available<v_line.quantity then raise exception 'Insufficient stock for purchase return' using errcode='23514'; end if;
  elsif v_doc.document_type='sale' then v_out:=v_line.quantity; if v_available<v_line.quantity then raise exception 'Insufficient stock for sale: available %, requested %',v_available,v_line.quantity using errcode='23514'; end if;
  elsif v_doc.document_type='sale_return' then v_in:=v_line.quantity;
  end if;
  insert into public.erp_business_workspace_stock_movements(workspace_id,warehouse_id,item_link_id,document_id,movement_type,quantity_in,quantity_out,unit_cost,movement_date,created_by)
  values(v_doc.workspace_id,v_line.warehouse_id,v_line.item_link_id,v_doc.id,v_doc.document_type,v_in,v_out,case when v_doc.document_type in ('sale','sale_return') then v_avg_cost else v_line.unit_price end,v_doc.document_date,v_user);
 end loop;
 update public.erp_business_workspace_documents set status='posted',posted_by=v_user,posted_at=now(),updated_at=now() where id=v_doc.id and workspace_id=v_doc.workspace_id and status='approved';
 if private.can_access_business_workspace(v_doc.workspace_id,'audit.write') then
  insert into public.erp_business_workspace_audit_log(workspace_id,actor_user_id,action,entity_type,entity_id,details)
  values(v_doc.workspace_id,v_user,'post','document',v_doc.id::text,jsonb_build_object('document_no',v_doc.document_no,'document_type',v_doc.document_type,'total',v_doc.total));
 end if;
 return true;
end $$;
revoke all on function public.erp_post_business_workspace_document(uuid) from public,anon;
grant execute on function public.erp_post_business_workspace_document(uuid) to authenticated;
