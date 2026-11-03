-- Enforce that each workspace document and its lines use warehouses
-- belonging to the same branch as the document, in addition to tenant scope.
create or replace function private.enforce_business_workspace_document_location()
returns trigger
language plpgsql
set search_path=pg_catalog,public,private
as $$
declare
  v_document_branch uuid;
  v_warehouse_branch uuid;
begin
  if tg_table_name='erp_business_workspace_documents' then
    if new.branch_id is null or new.warehouse_id is null then
      raise exception 'A branch and warehouse are required for workspace operational documents'
        using errcode='23514';
    end if;
    select w.branch_id into v_warehouse_branch
    from public.erp_business_workspace_warehouses w
    where w.id=new.warehouse_id
      and w.workspace_id=new.workspace_id
      and w.is_active;
    if not found then
      raise exception 'The document warehouse is not active in this workspace'
        using errcode='23503';
    end if;
    if v_warehouse_branch is distinct from new.branch_id then
      raise exception 'The selected warehouse does not belong to the selected document branch'
        using errcode='23514';
    end if;
  elsif tg_table_name='erp_business_workspace_document_lines' then
    select d.branch_id into v_document_branch
    from public.erp_business_workspace_documents d
    where d.id=new.document_id and d.workspace_id=new.workspace_id;
    if not found then
      raise exception 'The document line parent is not available in this workspace'
        using errcode='23503';
    end if;
    select w.branch_id into v_warehouse_branch
    from public.erp_business_workspace_warehouses w
    where w.id=new.warehouse_id and w.workspace_id=new.workspace_id and w.is_active;
    if not found then
      raise exception 'The document line warehouse is not active in this workspace'
        using errcode='23503';
    end if;
    if v_warehouse_branch is distinct from v_document_branch then
      raise exception 'The document line warehouse must belong to the document branch'
        using errcode='23514';
    end if;
  end if;
  return new;
end;
$$;

revoke all on function private.enforce_business_workspace_document_location() from public,anon,authenticated;

drop trigger if exists erp_biz_ws_document_location_guard on public.erp_business_workspace_documents;
create trigger erp_biz_ws_document_location_guard
before insert or update of workspace_id,branch_id,warehouse_id
on public.erp_business_workspace_documents
for each row execute function private.enforce_business_workspace_document_location();

drop trigger if exists erp_biz_ws_document_line_location_guard on public.erp_business_workspace_document_lines;
create trigger erp_biz_ws_document_line_location_guard
before insert or update of workspace_id,document_id,warehouse_id
on public.erp_business_workspace_document_lines
for each row execute function private.enforce_business_workspace_document_location();
