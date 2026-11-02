drop policy if exists erp_cash_orders_operator_insert on public.erp_cash_orders;
create policy erp_cash_orders_operator_insert on public.erp_cash_orders for insert to authenticated
with check (
  (created_by is null or created_by=(select auth.uid())) and
  public.erp_user_has_company_role(company_id,array['owner','admin','manager','operator','accountant']::text[]) and
  (
    (instrument_type='cheque' and status='converted' and cheque_id is not null)
    or status='draft'
    or (status='approved' and exists(select 1 from public.erp_financial_policies p where p.company_id=erp_cash_orders.company_id and p.require_cash_order_approval=false))
  ) and
  (
    instrument_type='cheque'
    or not exists(select 1 from public.erp_financial_policies p where p.company_id=erp_cash_orders.company_id and p.cash_issue_mode='sales_order_only')
    or exists(select 1 from public.erp_sales_documents d where d.id=erp_cash_orders.sales_document_id and d.company_id=erp_cash_orders.company_id and d.document_type='order')
  )
);
