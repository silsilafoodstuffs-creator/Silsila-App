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
  ),

  sales_document_metrics as (
    select count(*) filter (where document_type = 'invoice')::integer as invoice_count,
      coalesce(avg(grand_total) filter (where document_type = 'invoice'),0) as average_invoice,
      coalesce(sum(grand_total) filter (where document_type = 'return'),0) as return_total,
      coalesce(sum(grand_total) filter (where document_type = 'invoice'),0) as gross_invoice_total
    from sales
  ),
  top_customer_metrics as (
    select coalesce(jsonb_agg(jsonb_build_object('name', q.party_name, 'sales', q.total) order by q.total desc), '[]'::jsonb) as rows
    from (select p.party_name, sum(case when d.document_type = 'return' then -d.grand_total else d.grand_total end) as total
      from sales d join public.erp_parties p on p.id = d.customer_id and p.company_id = p_company_id
      where d.document_type in ('invoice','return') group by p.party_name order by total desc limit 5) q
  ),
  top_item_metrics as (
    select coalesce(jsonb_agg(jsonb_build_object('name', q.item_name, 'sales', q.total) order by q.total desc), '[]'::jsonb) as rows
    from (select i.item_name, sum(case when d.document_type = 'return' then -l.line_total else l.line_total end) as total
      from sales d join public.erp_sales_lines l on l.document_id = d.id
      join public.erp_items i on i.id = l.item_id and i.company_id = p_company_id
      where d.document_type in ('invoice','return') group by i.item_name order by total desc limit 5) q
  ),
  stock_by_item as (
    select m.item_id, sum(m.quantity_in-m.quantity_out) as quantity
    from public.erp_inventory_movements m where m.company_id = p_company_id group by m.item_id
  ),
  reorder_metrics as (
    select count(*)::integer as item_count from public.erp_items i
    left join stock_by_item s on s.item_id = i.id
    where i.company_id = p_company_id and i.is_active = true and i.reorder_level > 0
      and coalesce(s.quantity,0) <= i.reorder_level
  ),
  expiry_metrics as (
    select count(*)::integer as batch_count from (
      select item_id, batch_number, expiry_date from public.erp_inventory_movements
      where company_id = p_company_id and expiry_date between current_date and current_date + 30
      group by item_id, batch_number, expiry_date having sum(quantity_in-quantity_out) > 0
    ) b
  ),
  slow_moving_metrics as (
    select count(*)::integer as item_count from stock_by_item s
    join public.erp_items i on i.id = s.item_id and i.company_id = p_company_id
    where s.quantity > 0 and i.is_active = true
      and not exists (select 1 from public.erp_inventory_movements recent
        where recent.company_id = p_company_id and recent.item_id = i.id
          and recent.quantity_out > 0 and recent.movement_date >= current_date - 90)
  ),
  fulfillment_metrics as (
    select count(*) filter (where lower(coalesce(status,'')) not in
      ('delivered','completed','complete','cancelled','canceled','مُسلّم','تم التسليم','مكتمل','ملغي'))::integer as pending_count
    from public.erp_sales_fulfillment_documents where company_id = p_company_id
  ),
  attendance_metrics as (
    select count(*)::integer as records_count,
      count(*) filter (where lower(coalesce(attendance_status,'')) in
        ('present','late','حاضر','متأخر','موجود'))::integer as present_count
    from public.erp_attendance_records
    where company_id = p_company_id and work_date >= p_month_start and work_date < p_month_end
  ),
  payroll_metrics as (
    select coalesce(sum(net_total),0) as net_total from public.erp_payroll_runs
    where company_id = p_company_id and period_start < p_month_end and period_end >= p_month_start
      and lower(status) in ('approved','posted','paid','معتمد','مرحّل','مدفوع')
  ),
  supplier_payables as (
    select coalesce(sum(greatest(d.grand_total - d.paid_total, 0)), 0) as outstanding,
      count(*) filter (where d.due_date < current_date and greatest(d.grand_total - d.paid_total, 0) > 0)::integer as overdue_documents
    from public.erp_purchase_documents d
    where d.company_id = p_company_id and d.status = 'posted' and d.is_demo_data = false
  ),
  credit_exposure as (
    select p.id, p.party_name, coalesce(p.credit_limit, 0) as credit_limit,
      coalesce(sum(case when d.document_type = 'invoice' then greatest(d.grand_total - d.paid_total, 0)
        when d.document_type = 'return' then -d.grand_total else 0 end), 0) as outstanding
    from public.erp_parties p
    join public.erp_sales_documents d on d.customer_id = p.id and d.company_id = p_company_id
      and d.status = 'posted' and d.is_demo_data = false
    where p.company_id = p_company_id and p.party_kind = 'customer'
    group by p.id, p.party_name, p.credit_limit
  ),
  credit_limit_metrics as (
    select count(*) filter (where credit_limit > 0 and outstanding > credit_limit)::integer as exceeded_count
    from credit_exposure
  ),
  branch_sales_metrics as (
    select coalesce(jsonb_agg(jsonb_build_object('branch_id', q.branch_id, 'name', q.branch_name, 'sales', q.net_sales)
      order by q.net_sales desc), '[]'::jsonb) as rows
    from (select b.id as branch_id, b.branch_name,
      sum(case when s.document_type = 'return' then -s.grand_total else s.grand_total end) as net_sales
      from sales s join public.erp_branches b on b.id = s.branch_id and b.company_id = p_company_id
      where s.document_type in ('invoice', 'return') group by b.id, b.branch_name) q
  ),
  item_profit_metrics as (
    select coalesce(jsonb_agg(jsonb_build_object('name', q.item_name, 'profit', q.net_profit, 'sales', q.net_sales)
      order by q.net_profit desc), '[]'::jsonb) as rows
    from (select i.item_name,
      sum(case when d.document_type = 'return' then -1 else 1 end *
        (l.line_total - coalesce(l.base_quantity, l.quantity) * i.purchase_price)) as net_profit,
      sum(case when d.document_type = 'return' then -l.line_total else l.line_total end) as net_sales
      from sales d join public.erp_sales_lines l on l.document_id = d.id
      join public.erp_items i on i.id = l.item_id and i.company_id = p_company_id
      where d.document_type in ('invoice', 'return') group by i.item_name order by net_profit desc limit 5) q
  ),
  category_sales_metrics as (
    select coalesce(jsonb_agg(jsonb_build_object('name', q.category_name, 'sales', q.net_sales)
      order by q.net_sales desc), '[]'::jsonb) as rows
    from (select coalesce(c.category_name, 'غير مصنف') as category_name,
      sum(case when d.document_type = 'return' then -l.line_total else l.line_total end) as net_sales
      from sales d join public.erp_sales_lines l on l.document_id = d.id
      join public.erp_items i on i.id = l.item_id and i.company_id = p_company_id
      left join public.erp_item_categories c on c.id = i.category_id and c.company_id = p_company_id
      where d.document_type in ('invoice', 'return') group by coalesce(c.category_name, 'غير مصنف')) q
  ),
  cost_of_sales_metrics as (
    select coalesce(sum(case when d.document_type = 'return' then -1 else 1 end *
      coalesce(l.base_quantity, l.quantity) * i.purchase_price), 0) as cost_of_sales
    from sales d join public.erp_sales_lines l on l.document_id = d.id
    join public.erp_items i on i.id = l.item_id and i.company_id = p_company_id
    where d.document_type in ('invoice', 'return')
  ),
  fulfillment_status_metrics as (
    select count(*) filter (where lower(coalesce(status,'')) in ('cancelled','canceled','ملغي','ملغى'))::integer as cancelled_count
    from public.erp_sales_fulfillment_documents where company_id = p_company_id
  ),
  master_data_quality as (
    select round(100.0 * coalesce(sum(filled_fields), 0) / nullif(sum(total_fields), 0), 1) as completeness_rate
    from (
      select
        (case when nullif(trim(p.party_name), '') is not null then 1 else 0 end +
         case when nullif(trim(p.party_code), '') is not null then 1 else 0 end +
         case when nullif(trim(p.phone), '') is not null then 1 else 0 end +
         case when nullif(trim(p.address), '') is not null then 1 else 0 end +
         case when p.party_kind is not null then 1 else 0 end) as filled_fields,
        5 as total_fields
      from public.erp_parties p where p.company_id = p_company_id and p.is_active = true
      union all
      select
        (case when nullif(trim(i.item_name), '') is not null then 1 else 0 end +
         case when nullif(trim(i.item_code), '') is not null then 1 else 0 end +
         case when nullif(trim(i.base_unit), '') is not null then 1 else 0 end +
         case when i.purchase_price is not null then 1 else 0 end +
         case when i.sale_price is not null then 1 else 0 end),
        5
      from public.erp_items i where i.company_id = p_company_id and i.is_active = true
      union all
      select
        (case when nullif(trim(b.branch_name), '') is not null then 1 else 0 end +
         case when nullif(trim(b.branch_code), '') is not null then 1 else 0 end +
         case when nullif(trim(b.phone), '') is not null then 1 else 0 end +
         case when nullif(trim(b.address), '') is not null then 1 else 0 end),
        4
      from public.erp_branches b where b.company_id = p_company_id and b.is_active = true
      union all
      select
        (case when nullif(trim(e.full_name), '') is not null then 1 else 0 end +
         case when nullif(trim(e.employee_code), '') is not null then 1 else 0 end +
         case when nullif(trim(e.job_title), '') is not null then 1 else 0 end +
         case when e.branch_id is not null then 1 else 0 end),
        4
      from public.erp_employees e where e.company_id = p_company_id and e.is_active = true
    ) quality_rows
  ),
  approval_metrics as (
    select (select count(*) from public.erp_sales_documents where company_id=p_company_id and status='draft' and is_demo_data=false)
      + (select count(*) from public.erp_purchase_documents where company_id=p_company_id and status='draft' and is_demo_data=false)
      + (select count(*) from public.erp_journal_entries where company_id=p_company_id and status='draft') as pending_count
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
    'cash_net_flow', cft.inflows - cft.outflows,
    'invoice_count', sdm.invoice_count,
    'average_invoice', sdm.average_invoice,
    'sales_return_total', sdm.return_total,
    'sales_return_rate', case when sdm.gross_invoice_total > 0 then sdm.return_total / sdm.gross_invoice_total * 100 else 0 end,
    'top_customers', tcm.rows,
    'top_items', tim.rows,
    'reorder_item_count', rm.item_count,
    'expiry_batch_count_30d', xm.batch_count,
    'slow_moving_item_count', sm.item_count,
    'fulfillment_pending_count', fm.pending_count,
    'attendance_records_count', am.records_count,
    'attendance_present_count', am.present_count,
    'attendance_rate', case when am.records_count > 0 then am.present_count::numeric / am.records_count * 100 else 0 end,
    'payroll_net_total', pm.net_total,
    'pending_approval_count', apm.pending_count,
    'supplier_payables', sp.outstanding,
    'supplier_overdue_documents', sp.overdue_documents,
    'credit_limit_exceeded_count', clm.exceeded_count,
    'branch_sales', bsm.rows,
    'top_profitable_items', ipm.rows,
    'category_sales', csm.rows,
    'inventory_turnover_rate', case when it.value > 0 then cosm.cost_of_sales / it.value else null end,
    'fulfillment_cancelled_count', fsm.cancelled_count,
    'data_completeness_rate', mdq.completeness_rate
  ) into v_result
  from sales_totals st
  cross join purchase_totals pt
  cross join margin_totals mt
  cross join inventory_total it
  cross join expense_totals et
  cross join fixed_asset_totals fat
  cross join cash_flow_totals cft
  cross join sales_document_metrics sdm
  cross join top_customer_metrics tcm
  cross join top_item_metrics tim
  cross join reorder_metrics rm
  cross join expiry_metrics xm
  cross join slow_moving_metrics sm
  cross join fulfillment_metrics fm
  cross join attendance_metrics am
  cross join payroll_metrics pm
  cross join approval_metrics apm
  cross join supplier_payables sp
  cross join credit_limit_metrics clm
  cross join branch_sales_metrics bsm
  cross join item_profit_metrics ipm
  cross join category_sales_metrics csm
  cross join cost_of_sales_metrics cosm
  cross join fulfillment_status_metrics fsm
  cross join master_data_quality mdq;

  return v_result;
end;
$$;

revoke all on function public.erp_get_executive_metrics(uuid,date,date) from public, anon;
grant execute on function public.erp_get_executive_metrics(uuid,date,date) to authenticated;
