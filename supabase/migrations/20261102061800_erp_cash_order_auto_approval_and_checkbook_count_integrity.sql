drop policy if exists erp_cash_orders_operator_insert on public.erp_cash_orders;
create policy erp_cash_orders_operator_insert on public.erp_cash_orders for insert to authenticated
with check (
  (created_by is null or created_by=(select auth.uid())) and
  public.erp_user_has_company_role(company_id,array['owner','admin','manager','operator','accountant']::text[]) and
  (
    status='draft' or
    (status='approved' and exists(
      select 1 from public.erp_financial_policies p
      where p.company_id=erp_cash_orders.company_id and p.require_cash_order_approval=false
    ))
  )
);

create or replace function public.erp_sync_checkbook_sheet_count()
returns trigger language plpgsql set search_path=public as $$
declare v_count integer;
begin
  select checkbook_sheet_count into v_count
  from public.erp_cashboxes
  where id=new.bank_cashbox_id and company_id=new.company_id and is_bank_account and is_active;
  if v_count is null then raise exception 'الحساب البنكي غير نشط أو غير صالح لدفاتر الشيكات'; end if;
  new.sheet_count := v_count;
  return new;
end;
$$;
drop trigger if exists erp_checkbook_sheet_count_sync on public.erp_checkbooks;
create trigger erp_checkbook_sheet_count_sync before insert or update of bank_cashbox_id,company_id,sheet_count
on public.erp_checkbooks for each row execute function public.erp_sync_checkbook_sheet_count();
