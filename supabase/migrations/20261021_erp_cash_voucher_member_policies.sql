
alter table public.erp_cash_vouchers enable row level security;
drop policy if exists erp_cash_vouchers_select_member on public.erp_cash_vouchers;
create policy erp_cash_vouchers_select_member on public.erp_cash_vouchers for select to authenticated using (public.erp_user_can_access_company(company_id));
drop policy if exists erp_cash_vouchers_insert_operator on public.erp_cash_vouchers;
create policy erp_cash_vouchers_insert_operator on public.erp_cash_vouchers for insert to authenticated
with check (status='draft' and (created_by is null or created_by=(select auth.uid()))
and public.erp_user_has_company_role(company_id,array['owner','admin','manager','operator','accountant']::text[]));
drop policy if exists erp_cash_vouchers_update_operator on public.erp_cash_vouchers;
drop policy if exists erp_cash_vouchers_delete_admin on public.erp_cash_vouchers;
grant select,insert on public.erp_cash_vouchers to authenticated;
