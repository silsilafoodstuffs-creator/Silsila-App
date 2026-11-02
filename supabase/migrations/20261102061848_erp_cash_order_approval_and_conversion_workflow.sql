drop policy if exists erp_cash_orders_operator_update on public.erp_cash_orders;
create policy erp_cash_orders_operator_update on public.erp_cash_orders for update to authenticated
using (status in ('draft','approved') and public.erp_user_has_company_role(company_id,array['owner','admin','manager','accountant']::text[]))
with check (status in ('draft','approved','converted','cancelled') and public.erp_user_has_company_role(company_id,array['owner','admin','manager','accountant']::text[]));

create or replace function public.erp_convert_cash_order(p_order_id uuid,p_cashbox_id uuid,p_counter_account_id uuid)
returns uuid language plpgsql security invoker set search_path=public as $$
declare o public.erp_cash_orders%rowtype; v_movement_id uuid; v_voucher_id uuid;
  v_from_type text; v_from_id uuid; v_from_name text; v_to_type text; v_to_id uuid; v_to_name text;
begin
  select * into o from public.erp_cash_orders where id=p_order_id for update;
  if not found then raise exception 'أمر الصرف أو التوريد غير موجود'; end if;
  if o.status not in ('approved','draft') then raise exception 'حالة الأمر لا تسمح بالتنفيذ'; end if;
  if o.status='draft' and coalesce((select require_cash_order_approval from public.erp_financial_policies where company_id=o.company_id),true) then raise exception 'يجب اعتماد أمر الصرف أولًا'; end if;
  if not public.erp_user_has_company_role(o.company_id,array['owner','admin','manager','accountant']::text[]) then raise exception 'ليست لديك صلاحية تنفيذ أمر الصرف'; end if;
  if o.order_type='receipt' then
    v_from_type:=o.party_type;v_from_id:=o.party_id;v_from_name:=o.party_name;v_to_type:='cashbox';v_to_id:=p_cashbox_id;
    select cashbox_name into v_to_name from public.erp_cashboxes where id=p_cashbox_id and company_id=o.company_id and not is_bank_account and is_active;
    if v_to_name is null then raise exception 'اختر خزينة نشطة للتوريد'; end if;
  else
    v_from_type:='cashbox';v_from_id:=p_cashbox_id;
    select cashbox_name into v_from_name from public.erp_cashboxes where id=p_cashbox_id and company_id=o.company_id and not is_bank_account and is_active;
    v_to_type:=o.party_type;v_to_id:=o.party_id;v_to_name:=o.party_name;
    if v_from_name is null then raise exception 'اختر خزينة نشطة للصرف'; end if;
  end if;
  v_movement_id:=public.erp_create_cash_movement(o.company_id,o.order_type,v_from_type,v_from_id,v_from_name,v_to_type,v_to_id,v_to_name,o.amount,'تنفيذ أمر رقم '||o.order_number||' - '||o.description,p_counter_account_id,current_date);
  select cash_voucher_id into v_voucher_id from public.erp_cash_movements where id=v_movement_id;
  update public.erp_cash_orders set status='converted',cash_voucher_id=v_voucher_id,updated_at=now() where id=o.id;
  return v_movement_id;
end; $$;
revoke all on function public.erp_convert_cash_order(uuid,uuid,uuid) from public,anon;
grant execute on function public.erp_convert_cash_order(uuid,uuid,uuid) to authenticated;
