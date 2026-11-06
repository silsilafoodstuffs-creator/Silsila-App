-- Server-side executive dashboard aggregates. Apply after ERP schema, operations and
-- company-membership security migrations. Values exclude demo documents and use posted records only.
create or replace function public.erp_get_executive_metrics(
  p_company_id uuid,
  p_month_start date default date_trunc('month', current_date)::date,
  p_month_end date default (date_trunc('month', current_date) + interval '1 month')::date
)
returns jsonb
language plpgsql
stable
security definer
set search_path = public
set row_security = off
as $$
declare
  v_result jsonb;
begin
  if auth.uid() is null then
    raise exception 'Authentication required';
  end if;
  if not public.erp_user_can_access_company(p_company_id) then
    raise exception 'You do not have access to this company';
  end if;
  if p_month_end <= p_month_start then
    raise exception 'Month end must be after month start';
  end if;

  with
  sales as (
    select d.*
    from public.erp_sales_documents d
    where d.company_id = p_company_id
      and d.status = 'posted'
      and d.is_demo_data = false
      and d.document_date >= p_month_start
      and d.document_date < p_month_end
  ),
  purchase_totals as (
    select coalesce(sum(case when d.document_type = 'return' then -d.grand_total else d.grand_total end),0) as total
    from public.erp_purchase_documents d
    where d.company_id = p_company_id
      and d.status = 'posted'
      and d.is_demo_data = false
      and d.document_date >= p_month_start
      and d.document_date < p_month_end
  ),
  sales_totals as (
    select
      coalesce(sum(case when document_type = 'return' then -grand_total else grand_total end),0) as sales,
      coalesce(sum(case when document_type = 'return' then -paid_total else paid_total end),0) as collections,
      coalesce(sum(case when document_type = 'invoice' then greatest(grand_total-paid_total,0) else 0 end),0) as receivables
    from sales
  ),
  margin_totals as (
    select coalesce(sum(
      case when d.document_type = 'return' then -1 else 1 end *
      (l.line_total - l.quantity * i.purchase_price)
    ),0) as gross_profit
    from sales d
    join public.erp_sales_lines l on l.document_id = d.id
    join public.erp_items i on i.id = l.item_id and i.company_id = p_company_id
  ),
  days as (
    select generate_series(current_date - 6, current_date, interval '1 day')::date as day
  ),
  daily as (
    select
      d.document_date as day,
      coalesce(sum(case when d.document_type = 'return' then -d.grand_total else d.grand_total end),0) as sales,
      coalesce(sum(case when d.document_type = 'return' then -d.paid_total else d.paid_total end),0) as collections
    from public.erp_sales_documents d
    where d.company_id = p_company_id
      and d.status = 'posted'
      and d.is_demo_data = false
      and d.document_date >= current_date - 6
      and d.document_date <= current_date
    group by d.document_date
  ),
  inventory_by_category as (
    select coalesce(g.category_name,'غير مصنف') as category_name,
      sum((m.quantity_in-m.quantity_out) * i.purchase_price) as value
    from public.erp_inventory_movements m
    join public.erp_items i on i.id = m.item_id and i.company_id = p_company_id
    left join public.erp_item_categories g on g.id = i.category_id and g.company_id = p_company_id
    where m.company_id = p_company_id
    group by coalesce(g.category_name,'غير مصنف')
    order by sum((m.quantity_in-m.quantity_out) * i.purchase_price) desc
    limit 7
  ),
  inventory_total as (
    select coalesce(sum((m.quantity_in-m.quantity_out) * i.purchase_price),0) as value
    from public.erp_inventory_movements m
    join public.erp_items i on i.id = m.item_id and i.company_id = p_company_id
    where m.company_id = p_company_id
  ),
  expense_totals as (
    select coalesce(sum(jl.debit - jl.credit),0) as total
    from public.erp_journal_entries je
    join public.erp_journal_lines jl on jl.entry_id = je.id
    join public.erp_accounts a on a.id = jl.account_id and a.company_id = p_company_id
    where je.company_id = p_company_id
      and je.status = 'posted'
      and je.entry_date >= p_month_start
      and je.entry_date < p_month_end
      and a.account_type = 'expense'
  ),
  fixed_asset_totals as (
    select
      coalesce(sum(acquisition_cost),0) as gross_value,
      coalesce(sum(accumulated_depreciation),0) as depreciation,
      coalesce(sum(net_book_value),0) as net_value
    from public.erp_fixed_assets
    where company_id = p_company_id
      and status in ('active','under_maintenance')
  ),
  cash_flow_totals as (
    select
      coalesce(sum(case when voucher_type = 'receipt' then amount else 0 end),0) as inflows,
      coalesce(sum(case when voucher_type = 'payment' then amount else 0 end),0) as outflows
    from public.erp_cash_vouchers
    where company_id = p_company_id
      and status = 'posted'
      and voucher_date >= p_month_start
      and voucher_date < p_month_end
  )
  select jsonb_build_object(
    'month_start', p_month_start,
    'month_end_exclusive', p_month_end,
    'sales', st.sales,
    'collections', st.collections,
    'receivables', st.receivables,
    'purchases', pt.total,
    'gross_profit_estimate', mt.gross_profit,
    'inventory_value_estimate', it.value,
    'daily_sales', coalesce((
      select jsonb_agg(coalesce(d.sales,0) order by days.day)
      from days left join daily d on d.day = days.day
    ), '[]'::jsonb),
    'daily_collections', coalesce((
      select jsonb_agg(coalesce(d.collections,0) order by days.day)
      from days left join daily d on d.day = days.day
    ), '[]'::jsonb),
    'inventory_category_labels', coalesce((
      select jsonb_agg(category_name order by value desc) from inventory_by_category
    ), '[]'::jsonb),
    'inventory_category_values', coalesce((
      select jsonb_agg(value order by value desc) from inventory_by_category
    ), '[]'::jsonb),
    'expenses', et.total,
    'fixed_assets_gross', fat.gross_value,
    'fixed_assets_depreciation', fat.depreciation,
    'fixed_assets_net', fat.net_value,
    'cash_inflows', cft.inflows,
    'cash_outflows', cft.outflows,
    'cash_net_flow', cft.inflows - cft.outflows
  ) into v_result
  from sales_totals st
  cross join purchase_totals pt
  cross join margin_totals mt
  cross join inventory_total it
  cross join expense_totals et
  cross join fixed_asset_totals fat
  cross join cash_flow_totals cft;

  return v_result;
end;
$$;

revoke all on function public.erp_get_executive_metrics(uuid,date,date) from public, anon;
grant execute on function public.erp_get_executive_metrics(uuid,date,date) to authenticated;
