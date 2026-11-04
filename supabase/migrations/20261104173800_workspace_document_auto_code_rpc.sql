-- Allow an empty document number so the workspace central-code trigger can assign it atomically.
begin;
create or replace function public.erp_create_business_workspace_document(
 p_workspace_id uuid,p_branch_id uuid,p_warehouse_id uuid,p_document_no text,p_document_type text,
 p_document_date date,p_counterparty_name text,p_notes text,p_lines jsonb,p_tax numeric default 0
) returns uuid language plpgsql security invoker set search_path=pg_catalog,public,auth,private
as $$
declare v_user uuid := (select auth.uid()); v_permission text; v_doc_id uuid; v_doc_no text;
 v_subtotal numeric:=0; v_discount numeric:=0; v_total numeric:=0; v_line jsonb;
 v_item_id uuid; v_line_wh uuid; v_qty numeric; v_price numeric; v_disc numeric; v_line_total numeric;
begin
 if v_user is null then raise exception 'Authentication required' using errcode='28000'; end if;
 if p_document_type not in ('purchase','purchase_return','sale','sale_return') then raise exception 'Unsupported document type' using errcode='22023'; end if;
 v_permission:=case when p_document_type in ('purchase','purchase_return') then 'purchases.manage' else 'sales.manage' end;
 if not private.can_access_business_workspace(p_workspace_id,v_permission) then raise exception 'Insufficient permission to create this document' using errcode='42501'; end if;
 if length(trim(coalesce(p_document_no,''))) > 80 then raise exception 'Document number is too long' using errcode='22023'; end if;
 if p_tax<0 then raise exception 'Tax cannot be negative' using errcode='22023'; end if;
 if jsonb_typeof(p_lines)<>'array' or jsonb_array_length(p_lines)=0 then raise exception 'At least one document line is required' using errcode='22023'; end if;
 if not exists(select 1 from public.erp_business_workspace_branches b where b.id=p_branch_id and b.workspace_id=p_workspace_id and b.is_active) then raise exception 'Branch is invalid for this workspace' using errcode='23503'; end if;
 if not exists(select 1 from public.erp_business_workspace_warehouses w where w.id=p_warehouse_id and w.workspace_id=p_workspace_id and w.is_active) then raise exception 'Warehouse is invalid for this workspace' using errcode='23503'; end if;
 insert into public.erp_business_workspace_documents(workspace_id,branch_id,warehouse_id,document_no,document_type,document_date,counterparty_name,notes,status,subtotal,discount,tax,total,created_by)
 values(p_workspace_id,p_branch_id,p_warehouse_id,coalesce(nullif(trim(coalesce(p_document_no,'')),''),''),p_document_type,coalesce(p_document_date,current_date),nullif(trim(coalesce(p_counterparty_name,'')),''),nullif(trim(coalesce(p_notes,'')),''),'draft',0,0,p_tax,p_tax,v_user)
 returning id, document_no into v_doc_id, v_doc_no;
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
  values(p_workspace_id,v_user,'create','document',v_doc_id::text,jsonb_build_object('document_no',v_doc_no,'document_type',p_document_type,'total',v_total,'line_count',jsonb_array_length(p_lines)));
 end if;
 return v_doc_id;
end $$;

revoke all on function public.erp_create_business_workspace_document(uuid,uuid,uuid,text,text,date,text,text,jsonb,numeric) from public, anon;
grant execute on function public.erp_create_business_workspace_document(uuid,uuid,uuid,text,text,date,text,text,jsonb,numeric) to authenticated;
commit;
