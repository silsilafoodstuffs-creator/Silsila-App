-- Composite tenant constraints and document-specific permissions for business workspaces.
begin;
alter table public.erp_business_workspace_branches add constraint biz_branch_id_workspace_uk unique(id,workspace_id);
alter table public.erp_business_workspace_warehouses add constraint biz_wh_id_workspace_uk unique(id,workspace_id);
alter table public.erp_business_workspace_item_links add constraint biz_item_link_id_workspace_uk unique(id,workspace_id);
alter table public.erp_business_workspace_documents add constraint biz_doc_id_workspace_uk unique(id,workspace_id);
alter table public.erp_business_workspace_departments add constraint biz_dept_id_workspace_uk unique(id,workspace_id);
alter table public.erp_business_workspace_warehouses add constraint biz_wh_branch_workspace_fk foreign key(branch_id,workspace_id) references public.erp_business_workspace_branches(id,workspace_id) on delete restrict;
alter table public.erp_business_workspace_documents add constraint biz_doc_branch_workspace_fk foreign key(branch_id,workspace_id) references public.erp_business_workspace_branches(id,workspace_id) on delete restrict;
alter table public.erp_business_workspace_documents add constraint biz_doc_warehouse_workspace_fk foreign key(warehouse_id,workspace_id) references public.erp_business_workspace_warehouses(id,workspace_id) on delete restrict;
alter table public.erp_business_workspace_document_lines add constraint biz_line_doc_workspace_fk foreign key(document_id,workspace_id) references public.erp_business_workspace_documents(id,workspace_id) on delete cascade;
alter table public.erp_business_workspace_document_lines add constraint biz_line_item_workspace_fk foreign key(item_link_id,workspace_id) references public.erp_business_workspace_item_links(id,workspace_id) on delete restrict;
alter table public.erp_business_workspace_document_lines add constraint biz_line_wh_workspace_fk foreign key(warehouse_id,workspace_id) references public.erp_business_workspace_warehouses(id,workspace_id) on delete restrict;
alter table public.erp_business_workspace_stock_openings add constraint biz_opening_wh_workspace_fk foreign key(warehouse_id,workspace_id) references public.erp_business_workspace_warehouses(id,workspace_id) on delete restrict;
alter table public.erp_business_workspace_stock_openings add constraint biz_opening_item_workspace_fk foreign key(item_link_id,workspace_id) references public.erp_business_workspace_item_links(id,workspace_id) on delete restrict;
alter table public.erp_business_workspace_stock_movements add constraint biz_movement_wh_workspace_fk foreign key(warehouse_id,workspace_id) references public.erp_business_workspace_warehouses(id,workspace_id) on delete restrict;
alter table public.erp_business_workspace_stock_movements add constraint biz_movement_item_workspace_fk foreign key(item_link_id,workspace_id) references public.erp_business_workspace_item_links(id,workspace_id) on delete restrict;
alter table public.erp_business_workspace_stock_movements add constraint biz_movement_doc_workspace_fk foreign key(document_id,workspace_id) references public.erp_business_workspace_documents(id,workspace_id) on delete restrict;
alter table public.erp_business_workspace_cash_movements add constraint biz_cash_branch_workspace_fk foreign key(branch_id,workspace_id) references public.erp_business_workspace_branches(id,workspace_id) on delete restrict;
alter table public.erp_business_workspace_departments add constraint biz_dept_parent_workspace_fk foreign key(parent_id,workspace_id) references public.erp_business_workspace_departments(id,workspace_id) on delete restrict;
alter table public.erp_business_workspace_employees add constraint biz_employee_dept_workspace_fk foreign key(department_id,workspace_id) references public.erp_business_workspace_departments(id,workspace_id) on delete set null;

alter policy workspace_select on public.erp_business_workspace_documents
using(private.can_access_business_workspace(workspace_id,
 case when document_type in ('purchase','purchase_return') then 'purchases.read'
      when document_type in ('sale','sale_return') then 'sales.read' else 'inventory.read' end));
alter policy workspace_insert on public.erp_business_workspace_documents
with check(private.can_access_business_workspace(workspace_id,
 case when document_type in ('purchase','purchase_return') then 'purchases.manage'
      when document_type in ('sale','sale_return') then 'sales.manage' else 'inventory.manage' end));
alter policy workspace_update on public.erp_business_workspace_documents
using(private.can_access_business_workspace(workspace_id,
 case when document_type in ('purchase','purchase_return') then 'purchases.manage'
      when document_type in ('sale','sale_return') then 'sales.manage' else 'inventory.manage' end))
with check(private.can_access_business_workspace(workspace_id,
 case when document_type in ('purchase','purchase_return') then 'purchases.manage'
      when document_type in ('sale','sale_return') then 'sales.manage' else 'inventory.manage' end));
alter policy workspace_delete on public.erp_business_workspace_documents
using(status='draft' and private.can_access_business_workspace(workspace_id,
 case when document_type in ('purchase','purchase_return') then 'purchases.manage'
      when document_type in ('sale','sale_return') then 'sales.manage' else 'inventory.manage' end));

alter policy workspace_select on public.erp_business_workspace_document_lines
using(exists(select 1 from public.erp_business_workspace_documents d
 where d.id=erp_business_workspace_document_lines.document_id
 and d.workspace_id=erp_business_workspace_document_lines.workspace_id
 and private.can_access_business_workspace(d.workspace_id,
 case when d.document_type in ('purchase','purchase_return') then 'purchases.read'
      when d.document_type in ('sale','sale_return') then 'sales.read' else 'inventory.read' end)));
alter policy workspace_insert on public.erp_business_workspace_document_lines
with check(exists(select 1 from public.erp_business_workspace_documents d
 where d.id=erp_business_workspace_document_lines.document_id
 and d.workspace_id=erp_business_workspace_document_lines.workspace_id and d.status='draft'
 and private.can_access_business_workspace(d.workspace_id,
 case when d.document_type in ('purchase','purchase_return') then 'purchases.manage'
      when d.document_type in ('sale','sale_return') then 'sales.manage' else 'inventory.manage' end)));
alter policy workspace_update on public.erp_business_workspace_document_lines
using(exists(select 1 from public.erp_business_workspace_documents d
 where d.id=erp_business_workspace_document_lines.document_id
 and d.workspace_id=erp_business_workspace_document_lines.workspace_id and d.status='draft'
 and private.can_access_business_workspace(d.workspace_id,
 case when d.document_type in ('purchase','purchase_return') then 'purchases.manage'
      when d.document_type in ('sale','sale_return') then 'sales.manage' else 'inventory.manage' end)))
with check(exists(select 1 from public.erp_business_workspace_documents d
 where d.id=erp_business_workspace_document_lines.document_id
 and d.workspace_id=erp_business_workspace_document_lines.workspace_id and d.status='draft'
 and private.can_access_business_workspace(d.workspace_id,
 case when d.document_type in ('purchase','purchase_return') then 'purchases.manage'
      when d.document_type in ('sale','sale_return') then 'sales.manage' else 'inventory.manage' end)));
alter policy workspace_delete on public.erp_business_workspace_document_lines
using(exists(select 1 from public.erp_business_workspace_documents d
 where d.id=erp_business_workspace_document_lines.document_id
 and d.workspace_id=erp_business_workspace_document_lines.workspace_id and d.status='draft'
 and private.can_access_business_workspace(d.workspace_id,
 case when d.document_type in ('purchase','purchase_return') then 'purchases.manage'
      when d.document_type in ('sale','sale_return') then 'sales.manage' else 'inventory.manage' end)));
commit;
