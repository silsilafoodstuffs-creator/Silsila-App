create or replace function public.erp_get_business_workspace_metrics(p_workspace_id uuid)
returns jsonb
language plpgsql
stable
security invoker
set search_path=pg_catalog,public,auth,private
as $$
declare
  v_user uuid := (select auth.uid());
  v_metrics jsonb;
begin
  if v_user is null then
    raise exception 'Authentication required' using errcode='28000';
  end if;
  if not private.can_access_business_workspace(p_workspace_id,'workspace.enter') then
    raise exception 'Workspace is not accessible' using errcode='42501';
  end if;

  select jsonb_build_object(
    'branches_count',
      case when private.can_access_business_workspace(p_workspace_id,'master.read')
             or private.can_access_business_workspace(p_workspace_id,'reports.read')
      then (select count(*) from public.erp_business_workspace_branches b
            where b.workspace_id=p_workspace_id and b.is_active
              and private.can_access_business_workspace_location(p_workspace_id,b.id,null))
      else null end,
    'warehouses_count',
      case when private.can_access_business_workspace(p_workspace_id,'master.read')
             or private.can_access_business_workspace(p_workspace_id,'reports.read')
      then (select count(*) from public.erp_business_workspace_warehouses wh
            where wh.workspace_id=p_workspace_id and wh.is_active
              and private.can_access_business_workspace_location(p_workspace_id,wh.branch_id,wh.id))
      else null end,
    'items_count',
      case when private.can_access_business_workspace(p_workspace_id,'master.read')
             or private.can_access_business_workspace(p_workspace_id,'reports.read')
      then (select count(*) from public.erp_business_workspace_item_links i
            where i.workspace_id=p_workspace_id and i.is_enabled)
      else null end,
    'members_count',
      case when private.can_access_business_workspace(p_workspace_id,'members.read')
      then (select count(*) from public.erp_business_workspace_members m
            where m.workspace_id=p_workspace_id and m.is_active and m.member_role<>'owner')
      else null end,
    'departments_count',
      case when private.can_access_business_workspace(p_workspace_id,'hr.read')
      then (select count(*) from public.erp_business_workspace_departments d
            where d.workspace_id=p_workspace_id and d.is_active)
      else null end,
    'employees_count',
      case when private.can_access_business_workspace(p_workspace_id,'hr.read')
      then (select count(*) from public.erp_business_workspace_employees e
            where e.workspace_id=p_workspace_id and e.is_active)
      else null end,
    'documents_count',
      (select count(*) from public.erp_business_workspace_documents d
       where d.workspace_id=p_workspace_id
         and (private.can_access_business_workspace(p_workspace_id,
           case when d.document_type in ('purchase','purchase_return') then 'purchases.read'
                when d.document_type in ('sale','sale_return') then 'sales.read'
                else 'inventory.read' end)
           or private.can_access_business_workspace(p_workspace_id,'reports.read'))
         and private.can_access_business_workspace_location(p_workspace_id,d.branch_id,d.warehouse_id)
      ),
    'posted_documents_count',
      (select count(*) from public.erp_business_workspace_documents d
       where d.workspace_id=p_workspace_id and d.status='posted'
         and (private.can_access_business_workspace(p_workspace_id,
           case when d.document_type in ('purchase','purchase_return') then 'purchases.read'
                when d.document_type in ('sale','sale_return') then 'sales.read'
                else 'inventory.read' end)
           or private.can_access_business_workspace(p_workspace_id,'reports.read'))
         and private.can_access_business_workspace_location(p_workspace_id,d.branch_id,d.warehouse_id)),
    'draft_documents_count',
      (select count(*) from public.erp_business_workspace_documents d
       where d.workspace_id=p_workspace_id and d.status='draft'
         and (private.can_access_business_workspace(p_workspace_id,
           case when d.document_type in ('purchase','purchase_return') then 'purchases.read'
                when d.document_type in ('sale','sale_return') then 'sales.read'
                else 'inventory.read' end)
           or private.can_access_business_workspace(p_workspace_id,'reports.read'))
         and private.can_access_business_workspace_location(p_workspace_id,d.branch_id,d.warehouse_id)),
    'sales_total',
      case when private.can_access_business_workspace(p_workspace_id,'sales.read')
             or private.can_access_business_workspace(p_workspace_id,'reports.read')
      then (select coalesce(sum(d.total),0) from public.erp_business_workspace_documents d
            where d.workspace_id=p_workspace_id and d.document_type='sale' and d.status='posted'
              and private.can_access_business_workspace_location(p_workspace_id,d.branch_id,d.warehouse_id))
      else null end,
    'purchases_total',
      case when private.can_access_business_workspace(p_workspace_id,'purchases.read')
             or private.can_access_business_workspace(p_workspace_id,'reports.read')
      then (select coalesce(sum(d.total),0) from public.erp_business_workspace_documents d
            where d.workspace_id=p_workspace_id and d.document_type='purchase' and d.status='posted'
              and private.can_access_business_workspace_location(p_workspace_id,d.branch_id,d.warehouse_id))
      else null end,
    'sales_returns_total',
      case when private.can_access_business_workspace(p_workspace_id,'sales.read')
             or private.can_access_business_workspace(p_workspace_id,'reports.read')
      then (select coalesce(sum(d.total),0) from public.erp_business_workspace_documents d
            where d.workspace_id=p_workspace_id and d.document_type='sale_return' and d.status='posted'
              and private.can_access_business_workspace_location(p_workspace_id,d.branch_id,d.warehouse_id))
      else null end,
    'purchase_returns_total',
      case when private.can_access_business_workspace(p_workspace_id,'purchases.read')
             or private.can_access_business_workspace(p_workspace_id,'reports.read')
      then (select coalesce(sum(d.total),0) from public.erp_business_workspace_documents d
            where d.workspace_id=p_workspace_id and d.document_type='purchase_return' and d.status='posted'
              and private.can_access_business_workspace_location(p_workspace_id,d.branch_id,d.warehouse_id))
      else null end,
    'cash_movements_count',
      case when private.can_access_business_workspace(p_workspace_id,'cash.read')
             or private.can_access_business_workspace(p_workspace_id,'reports.read')
      then (select count(*) from public.erp_business_workspace_cash_movements c
            where c.workspace_id=p_workspace_id
              and private.can_access_business_workspace_location(p_workspace_id,c.branch_id,null))
      else null end,
    'cash_in_total',
      case when private.can_access_business_workspace(p_workspace_id,'cash.read')
             or private.can_access_business_workspace(p_workspace_id,'reports.read')
      then (select coalesce(sum(c.amount),0) from public.erp_business_workspace_cash_movements c
            where c.workspace_id=p_workspace_id
              and c.movement_type in ('receipt','deposit','income','transfer_in')
              and private.can_access_business_workspace_location(p_workspace_id,c.branch_id,null))
      else null end,
    'cash_out_total',
      case when private.can_access_business_workspace(p_workspace_id,'cash.read')
             or private.can_access_business_workspace(p_workspace_id,'reports.read')
      then (select coalesce(sum(c.amount),0) from public.erp_business_workspace_cash_movements c
            where c.workspace_id=p_workspace_id
              and c.movement_type not in ('receipt','deposit','income','transfer_in')
              and private.can_access_business_workspace_location(p_workspace_id,c.branch_id,null))
      else null end,
    'stock_movements_count',
      case when private.can_access_business_workspace(p_workspace_id,'inventory.read')
             or private.can_access_business_workspace(p_workspace_id,'reports.read')
      then (select count(*) from public.erp_business_workspace_stock_movements sm
            where sm.workspace_id=p_workspace_id
              and private.can_access_business_workspace_location(p_workspace_id,null,sm.warehouse_id))
      else null end,
    'stock_net_value',
      case when private.can_access_business_workspace(p_workspace_id,'inventory.read')
             or private.can_access_business_workspace(p_workspace_id,'reports.read')
      then (select coalesce(sum((sm.quantity_in-sm.quantity_out)*sm.unit_cost),0)
            from public.erp_business_workspace_stock_movements sm
            where sm.workspace_id=p_workspace_id
              and private.can_access_business_workspace_location(p_workspace_id,null,sm.warehouse_id))
      else null end,
    'currency_code',
      coalesce((select w.settings->'workspace_policy'->>'currency_code'
                from public.erp_business_workspaces w where w.id=p_workspace_id),'EGP')
  ) into v_metrics;

  return v_metrics;
end;
$$;

revoke all on function public.erp_get_business_workspace_metrics(uuid) from public,anon;
grant execute on function public.erp_get_business_workspace_metrics(uuid) to authenticated;
