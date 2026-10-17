-- Payroll calculation, approval, and posting to the general ledger.
-- Apply after erp_hr_schema.sql, erp_journal_workflow.sql and erp_security_membership.sql.

create or replace function public.erp_recalculate_payroll_run(p_run_id uuid)
returns uuid
language plpgsql
security definer
set search_path = public
set row_security = off
as $$
declare
  v_run public.erp_payroll_runs%rowtype;
  v_count integer;
  v_gross numeric(16,2);
  v_deductions numeric(16,2);
  v_net numeric(16,2);
begin
  select * into v_run from public.erp_payroll_runs where id = p_run_id for update;
  if not found then raise exception 'مسير الرواتب غير موجود'; end if;
  if not public.erp_user_has_company_role(v_run.company_id, array['owner','admin','accountant']::text[]) then
    raise exception 'ليست لديك صلاحية مراجعة مسير الرواتب';
  end if;
  if v_run.status <> 'draft' then raise exception 'إعادة الحساب متاحة للمسودة فقط'; end if;

  select count(*)::integer,
    coalesce(sum(gross_amount),0)::numeric(16,2),
    coalesce(sum(deductions),0)::numeric(16,2),
    coalesce(sum(net_amount),0)::numeric(16,2)
  into v_count, v_gross, v_deductions, v_net
  from public.erp_payroll_lines where payroll_run_id = v_run.id;

  update public.erp_payroll_runs
  set employee_count = v_count, gross_total = v_gross,
      deduction_total = v_deductions, net_total = v_net, updated_at = now()
  where id = v_run.id;
  return v_run.id;
end;
$$;

create or replace function public.erp_approve_payroll_run(p_run_id uuid)
returns uuid
language plpgsql
security definer
set search_path = public
set row_security = off
as $$
declare
  v_run public.erp_payroll_runs%rowtype;
begin
  perform public.erp_recalculate_payroll_run(p_run_id);
  select * into v_run from public.erp_payroll_runs where id = p_run_id for update;
  if v_run.status <> 'draft' then raise exception 'يمكن اعتماد مسودة الرواتب فقط'; end if;
  if v_run.employee_count = 0 or v_run.gross_total <= 0 then
    raise exception 'لا يمكن اعتماد مسير رواتب بلا موظفين أو بقيمة صفرية';
  end if;
  update public.erp_payroll_runs
  set status = 'approved', approved_by = auth.uid(), approved_at = now(), updated_at = now()
  where id = v_run.id;
  return v_run.id;
end;
$$;

create or replace function public.erp_post_payroll_run(p_run_id uuid)
returns uuid
language plpgsql
security definer
set search_path = public
set row_security = off
as $$
declare
  v_run public.erp_payroll_runs%rowtype;
  v_lines jsonb := '[]'::jsonb;
  v_journal_id uuid;
begin
  select * into v_run from public.erp_payroll_runs where id = p_run_id for update;
  if not found then raise exception 'مسير الرواتب غير موجود'; end if;
  if not public.erp_user_has_company_role(v_run.company_id, array['owner','admin','accountant']::text[]) then
    raise exception 'ليست لديك صلاحية ترحيل الرواتب';
  end if;
  if v_run.status <> 'approved' then raise exception 'اعتمد مسير الرواتب قبل الترحيل'; end if;
  if v_run.journal_entry_id is not null then raise exception 'مسير الرواتب مرتبط بقيد بالفعل'; end if;
  if v_run.gross_total <= 0 or v_run.employee_count <= 0 then raise exception 'إجماليات مسير الرواتب غير صالحة'; end if;
  if v_run.expense_account_id is null then raise exception 'حدد حساب مصروف الرواتب'; end if;
  if v_run.net_total > 0 and v_run.payable_account_id is null then raise exception 'حدد حساب مستحقات الرواتب'; end if;
  if v_run.deduction_total > 0 and v_run.deductions_account_id is null then raise exception 'حدد حساب استقطاعات الرواتب'; end if;

  v_lines := v_lines || jsonb_build_array(jsonb_build_object(
    'account_id', v_run.expense_account_id,
    'description', 'مصروف مسير الرواتب ' || v_run.run_code,
    'debit', v_run.gross_total, 'credit', 0
  ));
  if v_run.net_total > 0 then
    v_lines := v_lines || jsonb_build_array(jsonb_build_object(
      'account_id', v_run.payable_account_id,
      'description', 'صافي مستحقات الرواتب ' || v_run.run_code,
      'debit', 0, 'credit', v_run.net_total
    ));
  end if;
  if v_run.deduction_total > 0 then
    v_lines := v_lines || jsonb_build_array(jsonb_build_object(
      'account_id', v_run.deductions_account_id,
      'description', 'استقطاعات مسير الرواتب ' || v_run.run_code,
      'debit', 0, 'credit', v_run.deduction_total
    ));
  end if;

  v_journal_id := public.erp_save_journal_draft(
    v_run.company_id, v_run.period_end, 'ترحيل مسير الرواتب ' || v_run.run_code, v_lines, null
  );
  perform public.erp_post_journal_entry(v_journal_id);

  update public.erp_payroll_runs
  set status = 'posted', journal_entry_id = v_journal_id, updated_at = now()
  where id = v_run.id;
  return v_journal_id;
end;
$$;

create or replace function public.erp_guard_payroll_run_update()
returns trigger
language plpgsql
set search_path = public
as $$
begin
  if old.company_id is distinct from new.company_id
     or old.run_code is distinct from new.run_code
     or old.period_start is distinct from new.period_start
     or old.period_end is distinct from new.period_end then
    raise exception 'لا يمكن تغيير الشركة أو كود مسير الرواتب أو فترته';
  end if;
  if old.status in ('posted','paid','cancelled') then
    raise exception 'مسير الرواتب المرحّل أو المصروف أو الملغي غير قابل للتعديل';
  end if;
  if new.status = 'approved' then
    if old.status <> 'draft' or new.approved_by is null or new.approved_at is null then
      raise exception 'اعتماد مسير الرواتب يجب أن يتم من إجراء الاعتماد';
    end if;
  elsif new.status = 'posted' then
    if old.status <> 'approved' or new.journal_entry_id is null or not exists (
      select 1 from public.erp_journal_entries j
      where j.id = new.journal_entry_id and j.company_id = new.company_id
        and j.status = 'posted' and j.entry_date = new.period_end
        and (select coalesce(sum(l.debit),0) from public.erp_journal_lines l where l.entry_id = j.id) = new.gross_total
        and (select coalesce(sum(l.credit),0) from public.erp_journal_lines l where l.entry_id = j.id) = new.gross_total
        and exists (select 1 from public.erp_journal_lines l where l.entry_id = j.id
          and l.account_id = new.expense_account_id and l.debit = new.gross_total and l.credit = 0)
        and (new.net_total = 0 or exists (select 1 from public.erp_journal_lines l where l.entry_id = j.id
          and l.account_id = new.payable_account_id and l.debit = 0 and l.credit = new.net_total))
        and (new.deduction_total = 0 or exists (select 1 from public.erp_journal_lines l where l.entry_id = j.id
          and l.account_id = new.deductions_account_id and l.debit = 0 and l.credit = new.deduction_total))
    ) then raise exception 'ترحيل مسير الرواتب يتطلب قيدًا محاسبيًا مطابقًا للإجماليات والحسابات'; end if;
  elsif new.status not in ('draft','cancelled') then
    raise exception 'انتقال حالة مسير الرواتب غير مسموح';
  end if;
  return new;
end;
$$;

drop trigger if exists erp_payroll_run_immutable_guard on public.erp_payroll_runs;
create trigger erp_payroll_run_immutable_guard
before update on public.erp_payroll_runs
for each row execute function public.erp_guard_payroll_run_update();

revoke all on function public.erp_recalculate_payroll_run(uuid) from public, anon;
revoke all on function public.erp_approve_payroll_run(uuid) from public, anon;
revoke all on function public.erp_post_payroll_run(uuid) from public, anon;
grant execute on function public.erp_recalculate_payroll_run(uuid) to authenticated;
grant execute on function public.erp_approve_payroll_run(uuid) to authenticated;
grant execute on function public.erp_post_payroll_run(uuid) to authenticated;
