-- Atomic posting of cash receipts, cash payments, and cashbox transfers.
-- Apply after erp_journal_workflow.sql, erp_cash_vouchers_schema.sql and erp_security_membership.sql.

create or replace function public.erp_post_cash_voucher(p_voucher_id uuid)
returns uuid
language plpgsql
security definer
set search_path = public
set row_security = off
as $$
declare
  v public.erp_cash_vouchers%rowtype;
  v_source_account uuid;
  v_target_account uuid;
  v_journal_id uuid;
  v_lines jsonb;
begin
  select * into v from public.erp_cash_vouchers where id = p_voucher_id for update;
  if not found then raise exception 'سند الخزينة غير موجود'; end if;
  if not public.erp_user_has_company_role(v.company_id, array['owner','admin','accountant']::text[]) then
    raise exception 'ليست لديك صلاحية ترحيل سندات الخزائن';
  end if;
  if v.status <> 'draft' then raise exception 'يمكن ترحيل المسودات فقط'; end if;
  if v.amount <= 0 then raise exception 'قيمة السند يجب أن تكون أكبر من صفر'; end if;

  select c.account_id into v_source_account
  from public.erp_cashboxes c
  join public.erp_accounts a on a.id = c.account_id and a.company_id = c.company_id
  where c.id = v.source_cashbox_id and c.company_id = v.company_id
    and c.is_active and a.is_active and a.is_postable;
  if v_source_account is null then raise exception 'حساب الخزينة المصدر غير صالح'; end if;

  if v.voucher_type = 'transfer' then
    select c.account_id into v_target_account
    from public.erp_cashboxes c
    join public.erp_accounts a on a.id = c.account_id and a.company_id = c.company_id
    where c.id = v.destination_cashbox_id and c.company_id = v.company_id
      and c.is_active and a.is_active and a.is_postable;
    if v_target_account is null or v_target_account = v_source_account then
      raise exception 'حسابا الخزينتين غير صالحين أو متطابقان';
    end if;
    v_lines := jsonb_build_array(
      jsonb_build_object('account_id', v_target_account, 'description', v.description, 'debit', v.amount, 'credit', 0, 'branch_id', v.branch_id),
      jsonb_build_object('account_id', v_source_account, 'description', v.description, 'debit', 0, 'credit', v.amount, 'branch_id', v.branch_id)
    );
  elsif v.voucher_type = 'receipt' then
    v_lines := jsonb_build_array(
      jsonb_build_object('account_id', v_source_account, 'description', v.description, 'debit', v.amount, 'credit', 0, 'branch_id', v.branch_id),
      jsonb_build_object('account_id', v.counter_account_id, 'description', v.description, 'debit', 0, 'credit', v.amount, 'party_id', v.party_id, 'branch_id', v.branch_id)
    );
  elsif v.voucher_type = 'payment' then
    v_lines := jsonb_build_array(
      jsonb_build_object('account_id', v.counter_account_id, 'description', v.description, 'debit', v.amount, 'credit', 0, 'party_id', v.party_id, 'branch_id', v.branch_id),
      jsonb_build_object('account_id', v_source_account, 'description', v.description, 'debit', 0, 'credit', v.amount)
    );
  else
    raise exception 'نوع سند الخزينة غير مدعوم';
  end if;

  v_journal_id := public.erp_save_journal_draft(
    v.company_id, v.voucher_date, v.description, v_lines, null
  );
  perform public.erp_post_journal_entry(v_journal_id);

  update public.erp_cash_vouchers
     set status = 'posted', journal_entry_id = v_journal_id,
         posted_by = auth.uid(), posted_at = now(), updated_at = now()
   where id = v.id;

  return v_journal_id;
end;
$$;

revoke all on function public.erp_post_cash_voucher(uuid) from public, anon;
grant execute on function public.erp_post_cash_voucher(uuid) to authenticated;

comment on function public.erp_post_cash_voucher(uuid) is
  'Posts a cash voucher and balanced journal entry atomically; a voucher cannot be posted twice.';
