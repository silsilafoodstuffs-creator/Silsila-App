-- Remove the explicitly named financial test fixtures created on 2026-11-06.
-- This includes the fake opening journal, test-only cashboxes/bank accounts,
-- unregistered checkbooks and the TST-prefixed chart-of-account branch.
do $$
declare
  v_cashbox_ids uuid[];
  v_checkbook_ids uuid[];
  v_journal_ids uuid[];
begin
  select coalesce(array_agg(id),array[]::uuid[]) into v_cashbox_ids
  from public.erp_cashboxes
  where cashbox_code in ('TSTCB10','TSTCB20','TSTCB30','TSTCB40','TSTCB50','TSTCB60')
    and cashbox_name ilike '%اختبار%';

  select coalesce(array_agg(id),array[]::uuid[]) into v_checkbook_ids
  from public.erp_checkbooks
  where bank_cashbox_id = any(v_cashbox_ids)
    and registered = false
    and registered_at is null;

  select coalesce(array_agg(e.id),array[]::uuid[]) into v_journal_ids
  from public.erp_journal_entries e
  where e.entry_number_display='Jrn00001'
    and e.description='قيد افتتاحي تجريبي متوازن'
    and e.status='posted'
    and e.entry_date=date '2026-11-06'
    and exists (
      select 1 from public.erp_journal_lines l
      join public.erp_accounts a on a.id=l.account_id
      where l.entry_id=e.id and a.account_code like 'TST%'
    );

  if exists (select 1 from public.erp_cheques where checkbook_id=any(v_checkbook_ids) or bank_cashbox_id=any(v_cashbox_ids) or settlement_cashbox_id=any(v_cashbox_ids))
     or exists (select 1 from public.erp_cash_vouchers where source_cashbox_id=any(v_cashbox_ids) or destination_cashbox_id=any(v_cashbox_ids))
     or exists (select 1 from public.erp_payment_methods where cashbox_id=any(v_cashbox_ids))
     or exists (select 1 from public.erp_users where cashbox_id=any(v_cashbox_ids))
     or exists (select 1 from public.erp_cash_movements where from_id=any(v_cashbox_ids) or to_id=any(v_cashbox_ids))
  then
    raise exception 'Test cashboxes are referenced by operational records; cleanup stopped.';
  end if;

  if exists (select 1 from public.erp_cash_vouchers where journal_entry_id=any(v_journal_ids))
     or exists (select 1 from public.erp_payroll_runs where journal_entry_id=any(v_journal_ids))
     or exists (select 1 from public.erp_asset_depreciation_runs where journal_entry_id=any(v_journal_ids))
     or exists (select 1 from public.erp_asset_disposals where journal_entry_id=any(v_journal_ids))
     or exists (select 1 from public.erp_construction_payment_certificates where journal_entry_id=any(v_journal_ids))
     or exists (select 1 from public.erp_cheques where journal_entry_id=any(v_journal_ids))
  then
    raise exception 'Test journal entry is referenced by another operational record; cleanup stopped.';
  end if;

  if exists (select 1 from public.erp_operational_account_mappings m
      where m.accounts_payable_account_id in(select id from public.erp_accounts where account_code like 'TST%')
         or m.accounts_receivable_account_id in(select id from public.erp_accounts where account_code like 'TST%')
         or m.cost_of_goods_sold_account_id in(select id from public.erp_accounts where account_code like 'TST%')
         or m.inventory_account_id in(select id from public.erp_accounts where account_code like 'TST%')
         or m.purchase_return_variance_account_id in(select id from public.erp_accounts where account_code like 'TST%')
         or m.purchase_tax_credit_account_id in(select id from public.erp_accounts where account_code like 'TST%')
         or m.sales_returns_account_id in(select id from public.erp_accounts where account_code like 'TST%')
         or m.sales_revenue_account_id in(select id from public.erp_accounts where account_code like 'TST%')
         or m.sales_tax_payable_account_id in(select id from public.erp_accounts where account_code like 'TST%'))
     or exists (select 1 from public.erp_asset_categories x where x.asset_account_id in(select id from public.erp_accounts where account_code like 'TST%') or x.accumulated_account_id in(select id from public.erp_accounts where account_code like 'TST%') or x.expense_account_id in(select id from public.erp_accounts where account_code like 'TST%'))
     or exists (select 1 from public.erp_fixed_assets x where x.asset_account_id in(select id from public.erp_accounts where account_code like 'TST%') or x.accumulated_account_id in(select id from public.erp_accounts where account_code like 'TST%') or x.expense_account_id in(select id from public.erp_accounts where account_code like 'TST%'))
     or exists (select 1 from public.erp_payroll_runs x where x.expense_account_id in(select id from public.erp_accounts where account_code like 'TST%') or x.deductions_account_id in(select id from public.erp_accounts where account_code like 'TST%') or x.payable_account_id in(select id from public.erp_accounts where account_code like 'TST%'))
  then
    raise exception 'TST accounts are referenced by operational configuration; cleanup stopped.';
  end if;

  delete from public.erp_journal_lines where entry_id=any(v_journal_ids);
  delete from public.erp_journal_entries where id=any(v_journal_ids);

  delete from public.erp_checkbooks where id=any(v_checkbook_ids);
  delete from public.erp_cashboxes where id=any(v_cashbox_ids);

  -- Delete leaf accounts first, then their parent groups.
  delete from public.erp_accounts where account_code in ('TST1110','TST1120','TST1130','TST1140','TST1150','TST1160','TST3100');
  delete from public.erp_accounts where account_code='TST1100';
  delete from public.erp_accounts where account_code in ('TST1000','TST2000','TST3000','TST4000','TST5000');
end
$$;
