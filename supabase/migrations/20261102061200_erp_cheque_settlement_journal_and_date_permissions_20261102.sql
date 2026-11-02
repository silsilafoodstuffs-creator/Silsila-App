alter table public.erp_cheques alter column due_date drop not null;
alter table public.erp_cash_orders add column if not exists instrument_type text not null default 'cash' check (instrument_type in ('cash','cheque'));
alter table public.erp_cash_orders add column if not exists cheque_id uuid references public.erp_cheques(id) on delete restrict;
alter table public.erp_cheques
  add column if not exists counter_account_id uuid references public.erp_accounts(id) on delete restrict,
  add column if not exists journal_entry_id uuid references public.erp_journal_entries(id) on delete restrict;

drop policy if exists erp_financial_policies_admin_write on public.erp_financial_policies;
drop policy if exists erp_financial_policies_admin_insert on public.erp_financial_policies;
drop policy if exists erp_financial_policies_admin_update on public.erp_financial_policies;
create policy erp_financial_policies_admin_insert on public.erp_financial_policies for insert to authenticated
with check (public.erp_user_has_company_role(company_id,array['owner','admin']::text[]));
create policy erp_financial_policies_admin_update on public.erp_financial_policies for update to authenticated
using (public.erp_user_has_company_role(company_id,array['owner','admin']::text[]))
with check (public.erp_user_has_company_role(company_id,array['owner','admin']::text[]));

drop function if exists public.erp_settle_cheque(uuid,text,date,text,uuid,text);
create or replace function public.erp_settle_cheque(
  p_cheque_id uuid,p_result text,p_settlement_date date,p_method text default 'bank',
  p_cashbox_id uuid default null,p_reference text default null,p_counter_account_id uuid default null
) returns uuid language plpgsql security invoker set search_path=public as $$
declare c public.erp_cheques%rowtype; v_cash_account uuid; v_branch uuid; v_journal uuid; v_lines jsonb;
begin
  select * into c from public.erp_cheques where id=p_cheque_id for update;
  if not found then raise exception 'الشيك غير موجود'; end if;
  if not public.erp_user_has_company_role(c.company_id,array['owner','admin','manager','accountant']::text[]) then raise exception 'ليست لديك صلاحية تسوية الشيكات'; end if;
  if c.cheque_type<>'bank' then raise exception 'شيكات الائتمان لا تظهر في متابعة الشيكات البنكية'; end if;
  if c.status not in ('issued','under_collection') then raise exception 'حالة الشيك لا تسمح بالتسوية'; end if;
  if p_result not in ('paid','returned','cashed_from_cashbox') or p_settlement_date is null then raise exception 'نتيجة أو تاريخ التسوية غير صحيح'; end if;
  if p_result='cashed_from_cashbox' and (p_method<>'cashbox' or p_cashbox_id is null) then raise exception 'حدد الخزينة التي تم الصرف منها'; end if;
  if p_result in ('paid','cashed_from_cashbox') then
    if p_counter_account_id is null then raise exception 'حدد الحساب المقابل لإثبات التسوية محاسبيًا'; end if;
    if p_method='bank' then
      select cb.account_id,cb.branch_id into v_cash_account,v_branch from public.erp_cashboxes cb
      join public.erp_accounts a on a.id=cb.account_id and a.company_id=cb.company_id
      where cb.id=c.bank_cashbox_id and cb.company_id=c.company_id and cb.is_active and cb.is_bank_account and a.is_active and a.is_postable;
    else
      select cb.account_id,cb.branch_id into v_cash_account,v_branch from public.erp_cashboxes cb
      join public.erp_accounts a on a.id=cb.account_id and a.company_id=cb.company_id
      where cb.id=p_cashbox_id and cb.company_id=c.company_id and cb.is_active and not cb.is_bank_account and a.is_active and a.is_postable;
    end if;
    if v_cash_account is null then raise exception 'حساب البنك أو الخزينة غير صالح'; end if;
    if not exists(select 1 from public.erp_accounts a where a.id=p_counter_account_id and a.company_id=c.company_id and a.is_active and a.is_postable) then raise exception 'الحساب المقابل غير صالح أو غير قابل للترحيل'; end if;
    if p_counter_account_id=v_cash_account then raise exception 'الحساب المقابل لا يمكن أن يساوي حساب البنك أو الخزينة'; end if;
    if c.direction='payment' then
      v_lines:=jsonb_build_array(
        jsonb_build_object('account_id',p_counter_account_id,'description','تسوية شيك رقم '||c.check_number,'debit',c.amount,'credit',0,'branch_id',v_branch),
        jsonb_build_object('account_id',v_cash_account,'description','تسوية شيك رقم '||c.check_number,'debit',0,'credit',c.amount,'branch_id',v_branch));
    else
      v_lines:=jsonb_build_array(
        jsonb_build_object('account_id',v_cash_account,'description','تحصيل شيك رقم '||c.check_number,'debit',c.amount,'credit',0,'branch_id',v_branch),
        jsonb_build_object('account_id',p_counter_account_id,'description','تحصيل شيك رقم '||c.check_number,'debit',0,'credit',c.amount,'branch_id',v_branch));
    end if;
    v_journal:=public.erp_save_journal_draft(c.company_id,p_settlement_date,'تسوية شيك رقم '||c.check_number,v_lines,null);
    perform public.erp_post_journal_entry(v_journal);
  end if;
  update public.erp_cheques set status=p_result,settlement_date=p_settlement_date,settlement_method=p_method,
    settlement_cashbox_id=case when p_method='cashbox' then p_cashbox_id else null end,
    settlement_reference=nullif(trim(p_reference),''),counter_account_id=p_counter_account_id,
    journal_entry_id=v_journal,updated_by=auth.uid(),updated_at=now() where id=p_cheque_id;
  return v_journal;
end; $$;
revoke all on function public.erp_settle_cheque(uuid,text,date,text,uuid,text,uuid) from public,anon;
grant execute on function public.erp_settle_cheque(uuid,text,date,text,uuid,text,uuid) to authenticated;

create or replace function public.erp_issue_cheque(
  p_cheque_id uuid,p_cheque_type text,p_direction text,p_issue_date date,p_due_date date,
  p_amount numeric,p_payee_type text,p_payee_id uuid,p_payee_name text,p_notes text default ''
) returns void language plpgsql security invoker set search_path=public as $$
declare c public.erp_cheques%rowtype; v_roles text[];
begin
  select * into c from public.erp_cheques where id=p_cheque_id for update;
  if not found then raise exception 'رقم الشيك غير موجود في دفتر مسجل'; end if;
  if c.status<>'available' then raise exception 'لا يمكن اختيار إلا شيك متاح غير مستخدم'; end if;
  if p_cheque_type not in ('bank','credit') or p_direction not in ('payment','receipt') then raise exception 'نوع الشيك أو اتجاهه غير صحيح'; end if;
  if p_cheque_type='credit' and not coalesce((select allow_credit_cheques from public.erp_financial_policies where company_id=c.company_id),true) then raise exception 'شيكات الائتمان غير مفعلة في السياسات المحاسبية'; end if;
  if not public.erp_user_has_company_role(c.company_id,array['owner','admin','manager','operator','accountant']::text[]) then raise exception 'ليست لديك صلاحية إصدار الشيك'; end if;
  if p_issue_date is null or p_due_date is null or p_due_date<p_issue_date or p_amount<=0 then raise exception 'راجع تاريخ الإصدار والاستحقاق والقيمة'; end if;
  select cheque_issue_date_edit_roles into v_roles from public.erp_financial_policies where company_id=c.company_id;
  if p_issue_date<>current_date and not public.erp_user_has_company_role(c.company_id,coalesce(v_roles,array['owner','admin','accountant']::text[])) then raise exception 'تعديل تاريخ إصدار الشيك غير مسموح لهذا المستخدم'; end if;
  update public.erp_cheques set cheque_type=p_cheque_type,direction=p_direction,issue_date=p_issue_date,due_date=p_due_date,
    amount=p_amount,payee_type=p_payee_type,payee_id=p_payee_id,payee_name=coalesce(p_payee_name,''),
    status=case when p_direction='receipt' then 'under_collection' else 'issued' end,
    notes=coalesce(p_notes,''),updated_by=auth.uid(),updated_at=now() where id=p_cheque_id;
end; $$;
revoke all on function public.erp_issue_cheque(uuid,text,text,date,date,numeric,text,uuid,text,text) from public,anon;
grant execute on function public.erp_issue_cheque(uuid,text,text,date,date,numeric,text,uuid,text,text) to authenticated;
