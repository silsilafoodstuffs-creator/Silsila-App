create or replace function public.erp_validate_payment_method_cashbox()
returns trigger
language plpgsql
set search_path = public
as $$
declare
  v_company_id uuid;
  v_is_bank boolean;
begin
  if new.cashbox_id is null then
    return new;
  end if;

  select c.company_id, c.is_bank_account
    into v_company_id, v_is_bank
  from public.erp_cashboxes c
  where c.id = new.cashbox_id;

  if not found or v_company_id <> new.company_id then
    raise exception 'الخزينة أو الحساب البنكي المحدد لا يتبع الشركة الحالية'
      using errcode = '23514';
  end if;

  if new.method_type = 'bank_transfer' and not v_is_bank then
    raise exception 'طريقة التحويل البنكي يجب ربطها بحساب بنكي'
      using errcode = '23514';
  end if;

  return new;
end;
$$;

drop trigger if exists erp_payment_methods_cashbox_guard on public.erp_payment_methods;
create trigger erp_payment_methods_cashbox_guard
before insert or update of company_id, cashbox_id, method_type
on public.erp_payment_methods
for each row execute function public.erp_validate_payment_method_cashbox();
