-- reports.read grants read-only access to operational source data needed
-- by the workspace report center. It never grants write permissions and
-- keeps branch/warehouse restrictions in force.
alter policy workspace_select on public.erp_business_workspace_branches
using (
  (private.can_access_business_workspace(workspace_id,'master.read')
   or private.can_access_business_workspace(workspace_id,'reports.read'))
  and private.can_access_business_workspace_location(workspace_id,id,null)
);

alter policy workspace_select on public.erp_business_workspace_warehouses
using (
  (private.can_access_business_workspace(workspace_id,'master.read')
   or private.can_access_business_workspace(workspace_id,'reports.read'))
  and private.can_access_business_workspace_location(workspace_id,branch_id,id)
);

alter policy workspace_select on public.erp_business_workspace_item_links
using (
  private.can_access_business_workspace(workspace_id,'master.read')
  or private.can_access_business_workspace(workspace_id,'reports.read')
);

alter policy workspace_select on public.erp_business_workspace_stock_openings
using (
  (private.can_access_business_workspace(workspace_id,'inventory.read')
   or private.can_access_business_workspace(workspace_id,'reports.read'))
  and private.can_access_business_workspace_location(workspace_id,null,warehouse_id)
);

alter policy workspace_select on public.erp_business_workspace_stock_movements
using (
  (private.can_access_business_workspace(workspace_id,'inventory.read')
   or private.can_access_business_workspace(workspace_id,'reports.read'))
  and private.can_access_business_workspace_location(workspace_id,null,warehouse_id)
);

alter policy workspace_select on public.erp_business_workspace_cash_movements
using (
  (private.can_access_business_workspace(workspace_id,'cash.read')
   or private.can_access_business_workspace(workspace_id,'reports.read'))
  and private.can_access_business_workspace_location(workspace_id,branch_id,null)
);

alter policy workspace_select on public.erp_business_workspace_documents
using (
  (private.can_access_business_workspace(workspace_id,
    case
      when document_type in ('purchase','purchase_return') then 'purchases.read'
      when document_type in ('sale','sale_return') then 'sales.read'
      else 'inventory.read'
    end)
   or private.can_access_business_workspace(workspace_id,'reports.read'))
  and private.can_access_business_workspace_location(workspace_id,branch_id,warehouse_id)
);

alter policy workspace_select on public.erp_business_workspace_document_lines
using (
  exists (
    select 1
    from public.erp_business_workspace_documents d
    where d.id=erp_business_workspace_document_lines.document_id
      and d.workspace_id=erp_business_workspace_document_lines.workspace_id
      and (
        private.can_access_business_workspace(d.workspace_id,
          case
            when d.document_type in ('purchase','purchase_return') then 'purchases.read'
            when d.document_type in ('sale','sale_return') then 'sales.read'
            else 'inventory.read'
          end)
        or private.can_access_business_workspace(d.workspace_id,'reports.read')
      )
      and private.can_access_business_workspace_location(
        d.workspace_id,d.branch_id,erp_business_workspace_document_lines.warehouse_id)
  )
);
