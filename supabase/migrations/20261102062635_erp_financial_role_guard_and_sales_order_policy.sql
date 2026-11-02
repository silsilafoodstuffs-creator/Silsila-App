drop policy if exists erp_cash_orders_operator_insert on public.erp_cash_orders;
create policy erp_cash_orders_operator_insert on public.erp_cash_orders for insert to authenticated
with check (
  (created_by is null or created_by=(select auth.uid())) and
  public.erp_user_has_company_role(company_id,array['owner','admin','manager','operator','accountant']::text[]) and
  (status='draft' or (status='approved' and exists(select 1 from public.erp_financial_policies p where p.company_id=erp_cash_orders.company_id and p.require_cash_order_approval=false))) and
  (not exists(select 1 from public.erp_financial_policies p where p.company_id=erp_cash_orders.company_id and p.cash_issue_mode='sales_order_only')
   or exists(select 1 from public.erp_sales_documents d where d.id=erp_cash_orders.sales_document_id and d.company_id=erp_cash_orders.company_id and d.document_type='order'))
);

create or replace function public.erp_guard_cheque_mutations()
returns trigger language plpgsql security invoker set search_path=public as $$
declare v_edit_roles text[]; v_date_roles text[];
begin
  if old.status in ('paid','returned','cashed_from_cashbox','cancelled') then raise exception 'الشيك المسوى أو المرتد أو الملغى لا يقبل أي تعديل'; end if;
  if new.company_id<>old.company_id or new.bank_cashbox_id<>old.bank_cashbox_id or new.check_number<>old.check_number or new.checkbook_id is distinct from old.checkbook_id then raise exception 'لا يمكن تغيير الشركة أو الحساب البنكي أو سيريال الشيك بعد تسجيله'; end if;
  select cheque_edit_roles,cheque_issue_date_edit_roles into v_edit_roles,v_date_roles from public.erp_financial_policies where company_id=old.company_id;
  if old.status='available' and new.status in ('issued','under_collection') then
    if not public.erp_user_has_company_role(old.company_id,array['owner','admin','manager','operator','accountant']::text[]) then raise exception 'ليست لديك صلاحية إصدار الشيك'; end if;
  elsif (new.issue_date is distinct from old.issue_date or new.due_date is distinct from old.due_date or new.amount is distinct from old.amount or
    new.payee_type is distinct from old.payee_type or new.payee_id is distinct from old.payee_id or new.payee_name is distinct from old.payee_name or
    new.notes is distinct from old.notes or new.cheque_type is distinct from old.cheque_type or new.direction is distinct from old.direction) then
    if not public.erp_user_has_company_role(old.company_id,coalesce(v_edit_roles,array['owner','admin','accountant']::text[])) then raise exception 'تعديل بيانات الشيك غير مسموح لهذا المستخدم'; end if;
  end if;
  if new.issue_date is distinct from old.issue_date and not public.erp_user_has_company_role(old.company_id,coalesce(v_date_roles,array['owner','admin','accountant']::text[])) then raise exception 'تعديل تاريخ إصدار الشيك غير مسموح لهذا المستخدم'; end if;
  if new.status in ('paid','cashed_from_cashbox') and new.journal_entry_id is null then raise exception 'يجب إنشاء القيد المحاسبي قبل إغلاق الشيك'; end if;
  if new.status in ('paid','returned','cashed_from_cashbox') and new.settlement_date is null then raise exception 'تاريخ التسوية مطلوب'; end if;
  return new;
end; $$;
drop trigger if exists erp_cheques_mutation_guard on public.erp_cheques;
create trigger erp_cheques_mutation_guard before update on public.erp_cheques for each row execute function public.erp_guard_cheque_mutations();

create or replace function public.erp_convert_cash_order(p_order_id uuid,p_cashbox_id uuid,p_counter_account_id uuid)
returns uuid language plpgsql security invoker set search_path=public as $$
declare o public.erp_cash_orders%rowtype; v_movement_id uuid; v_voucher_id uuid; v_from_type text; v_from_id uuid; v_from_name text; v_to_type text; v_to_id uuid; v_to_name text; v_mode text;
begin
  select * into o from public.erp_cash_orders where id=p_order_id for update;
  if not found then raise exception 'أمر الصرف أو التوريد غير موجود'; end if;
  if o.status not in ('approved','draft') then raise exception 'حالة الأمر لا تسمح بالتنفيذ'; end if;
  select cash_issue_mode into v_mode from public.erp_financial_policies where company_id=o.company_id;
  if v_mode='sales_order_only' and not exists(select 1 from public.erp_sales_documents d where d.id=o.sales_document_id and d.company_id=o.company_id and d.document_type='order') then raise exception 'السياسة تشترط ربط الأمر بأمر بيع تابع لنفس الشركة'; end if;
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
