grant delete on public.erp_business_workspace_counterparties to authenticated;
drop policy if exists erp_ws_counterparties_delete on public.erp_business_workspace_counterparties;
create policy erp_ws_counterparties_delete
on public.erp_business_workspace_counterparties
for delete to authenticated
using (
  private.can_access_business_workspace(
    workspace_id,
    case when party_type='customer' then 'customers.manage' else 'suppliers.manage' end
  )
);
