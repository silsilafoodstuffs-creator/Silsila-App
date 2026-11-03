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
