alter table public.erp_cash_movements
  add column if not exists counter_account_id uuid references public.erp_accounts(id) on delete restrict;

drop policy if exists erp_cash_movements_operator_update_link on public.erp_cash_movements;
create policy erp_cash_movements_operator_update_link on public.erp_cash_movements for update to authenticated
using (cash_voucher_id is null and created_by=(select auth.uid()) and
  public.erp_user_has_company_role(company_id,array['owner','admin','manager','operator','accountant']::text[]))
with check (cash_voucher_id is not null and created_by=(select auth.uid()) and
  public.erp_user_has_company_role(company_id,array['owner','admin','manager','operator','accountant']::text[]));

create or replace function public.erp_guard_cash_movement_voucher_link()
returns trigger language plpgsql set search_path=public as $$
begin
  if old.cash_voucher_id is not null or new.cash_voucher_id is null
    or (to_jsonb(old) - 'cash_voucher_id') <> (to_jsonb(new) - 'cash_voucher_id') then
    raise exception 'لا يسمح بتعديل الحركة النقدية بعد تسجيلها؛ الربط بسند الخزينة فقط مسموح مرة واحدة';
  end if;
  return new;
end;
$$;
drop trigger if exists erp_cash_movement_link_guard on public.erp_cash_movements;
create trigger erp_cash_movement_link_guard before update on public.erp_cash_movements
for each row execute function public.erp_guard_cash_movement_voucher_link();

create or replace function public.erp_create_cash_movement(
  p_company_id uuid,p_movement_type text,p_from_type text,p_from_id uuid,p_from_name text,
  p_to_type text,p_to_id uuid,p_to_name text,p_amount numeric,p_description text default '',
  p_counter_account_id uuid default null,p_movement_date date default current_date
) returns uuid language plpgsql security invoker set search_path=public as $$
declare v_movement_id uuid; v_movement_no bigint; v_movement_number text; v_voucher_id uuid;
  v_source_cashbox uuid; v_destination_cashbox uuid; v_party_id uuid; v_branch uuid;
begin
  if not public.erp_user_has_company_role(p_company_id,array['owner','admin','manager','operator','accountant']::text[]) then raise exception 'ليست لديك صلاحية تسجيل الحركة النقدية'; end if;
  if p_amount is null or p_amount<=0 then raise exception 'قيمة الحركة يجب أن تكون موجبة فقط'; end if;
  if p_movement_date is null then raise exception 'تاريخ الحركة مطلوب'; end if;
  if p_movement_type not in ('receipt','payment','transfer') then raise exception 'نوع الحركة غير صحيح'; end if;
  if p_from_type not in ('supplier','customer','expense','bank','cashbox') or p_to_type not in ('supplier','customer','expense','bank','cashbox') then raise exception 'نوع الجهة غير صحيح'; end if;
  if p_movement_type='receipt' then
    if p_to_type not in ('bank','cashbox') then raise exception 'سند القبض يجب أن يورد إلى بنك أو خزينة'; end if;
    v_source_cashbox:=p_to_id; if p_from_type in ('supplier','customer') then v_party_id:=p_from_id; end if;
  elsif p_movement_type='payment' then
    if p_from_type not in ('bank','cashbox') then raise exception 'سند الصرف يجب أن يصدر من بنك أو خزينة'; end if;
    v_source_cashbox:=p_from_id; if p_to_type in ('supplier','customer') then v_party_id:=p_to_id; end if;
  else
    if p_from_type not in ('bank','cashbox') or p_to_type not in ('bank','cashbox') or p_from_id=p_to_id then raise exception 'التحويل يجب أن يكون بين خزنتين أو حسابين مختلفين'; end if;
    v_source_cashbox:=p_from_id; v_destination_cashbox:=p_to_id;
  end if;
  if not exists(select 1 from public.erp_cashboxes cb where cb.id=v_source_cashbox and cb.company_id=p_company_id and cb.is_active) then raise exception 'الخزينة أو البنك المصدر غير صالح'; end if;
  if v_destination_cashbox is not null and not exists(select 1 from public.erp_cashboxes cb where cb.id=v_destination_cashbox and cb.company_id=p_company_id and cb.is_active) then raise exception 'الخزينة أو البنك الوجهة غير صالح'; end if;
  if p_movement_type<>'transfer' and (p_counter_account_id is null or not exists(select 1 from public.erp_accounts a where a.id=p_counter_account_id and a.company_id=p_company_id and a.is_active and a.is_postable)) then raise exception 'حدد الحساب المقابل الصحيح والقابل للترحيل'; end if;
  if v_party_id is not null and not exists(select 1 from public.erp_parties p where p.id=v_party_id and p.company_id=p_company_id and p.is_active) then raise exception 'العميل أو المورد المحدد غير صالح'; end if;
  insert into public.erp_cash_movements(company_id,movement_date,movement_type,from_type,from_id,from_name,to_type,to_id,to_name,amount,description,counter_account_id,created_by)
  values(p_company_id,p_movement_date,p_movement_type,p_from_type,p_from_id,p_from_name,p_to_type,p_to_id,p_to_name,p_amount,coalesce(p_description,''),p_counter_account_id,auth.uid())
  returning id,movement_no,movement_number into v_movement_id,v_movement_no,v_movement_number;
  select branch_id into v_branch from public.erp_cashboxes where id=v_source_cashbox and company_id=p_company_id;
  insert into public.erp_cash_vouchers(company_id,branch_id,voucher_number,voucher_date,voucher_type,source_cashbox_id,destination_cashbox_id,counter_account_id,party_id,amount,description,status,created_by)
  values(p_company_id,v_branch,v_movement_number,p_movement_date,p_movement_type,v_source_cashbox,v_destination_cashbox,p_counter_account_id,v_party_id,p_amount,coalesce(nullif(trim(p_description),''),'حركة نقدية رقم '||v_movement_number),'draft',auth.uid())
  returning id into v_voucher_id;
  update public.erp_cash_movements set cash_voucher_id=v_voucher_id where id=v_movement_id;
  return v_movement_id;
end; $$;
revoke all on function public.erp_create_cash_movement(uuid,text,text,uuid,text,text,uuid,text,numeric,text,uuid,date) from public,anon;
grant execute on function public.erp_create_cash_movement(uuid,text,text,uuid,text,text,uuid,text,numeric,text,uuid,date) to authenticated;
