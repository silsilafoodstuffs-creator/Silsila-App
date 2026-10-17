-- Controlled accounting reversal: preserve original posted entry and create a posted
-- opposite entry. Do not mark the original as reversed, because ledger reports include
-- posted entries only and both sides must remain visible for an auditable zero net effect.

create or replace function public.erp_reverse_journal_entry(
  p_entry_id uuid,
  p_reversal_date date,
  p_reason text
)
returns uuid
language plpgsql
security invoker
set search_path = public
as $$
declare
  v_original public.erp_journal_entries%rowtype;
  v_reversal_id uuid;
  v_line_count integer;
  v_debit numeric(18,2);
  v_credit numeric(18,2);
  v_reason text := nullif(trim(p_reason), '');
begin
  if p_entry_id is null or p_reversal_date is null then
    raise exception 'القيد الأصلي وتاريخ العكس مطلوبان';
  end if;
  if v_reason is null then
    raise exception 'سبب العكس مطلوب للتوثيق';
  end if;

  select * into v_original
  from public.erp_journal_entries
  where id = p_entry_id
  for update;

  if not found then
    raise exception 'القيد الأصلي غير موجود أو غير متاح';
  end if;
  if v_original.status <> 'posted' then
    raise exception 'يمكن عكس القيود المرحلة فقط';
  end if;
  if exists (
    select 1 from public.erp_journal_entries r
    where r.company_id = v_original.company_id
      and r.source_type = 'reversal'
      and r.source_id = v_original.id
  ) then
    raise exception 'تم إنشاء قيد عكس لهذا القيد من قبل';
  end if;
  if exists (
    select 1 from public.erp_fiscal_periods fp
    where fp.company_id = v_original.company_id
      and p_reversal_date between fp.starts_on and fp.ends_on
      and fp.status = 'closed'
  ) then
    raise exception 'لا يمكن إنشاء قيد عكس داخل فترة مالية مغلقة';
  end if;

  select count(*), coalesce(sum(debit), 0), coalesce(sum(credit), 0)
    into v_line_count, v_debit, v_credit
  from public.erp_journal_lines
  where entry_id = v_original.id;

  if v_line_count < 2 or v_debit <= 0 or v_debit <> v_credit then
    raise exception 'القيد الأصلي غير متوازن أو لا يحتوي على سطور كافية';
  end if;

  insert into public.erp_journal_entries (
    company_id, branch_id, fiscal_period_id, entry_date, description,
    source_type, source_id, status, created_by, posted_by, posted_at
  ) values (
    v_original.company_id,
    v_original.branch_id,
    (select fp.id from public.erp_fiscal_periods fp
     where fp.company_id = v_original.company_id
       and p_reversal_date between fp.starts_on and fp.ends_on
     order by fp.starts_on desc limit 1),
    p_reversal_date,
    'عكس القيد رقم ' || v_original.entry_number::text || ' — ' || v_reason,
    'reversal', v_original.id, 'posted', auth.uid(), auth.uid(), now()
  ) returning id into v_reversal_id;

  insert into public.erp_journal_lines (
    entry_id, account_id, description, debit, credit, party_id, branch_id
  )
  select
    v_reversal_id, jl.account_id,
    coalesce(nullif(trim(jl.description), ''), 'عكس قيد ' || v_original.entry_number::text),
    jl.credit, jl.debit, jl.party_id, jl.branch_id
  from public.erp_journal_lines jl
  where jl.entry_id = v_original.id;

  return v_reversal_id;
end;
$$;

revoke all on function public.erp_reverse_journal_entry(uuid,date,text) from public, anon;
grant execute on function public.erp_reverse_journal_entry(uuid,date,text) to authenticated;

comment on function public.erp_reverse_journal_entry(uuid,date,text) is
  'Creates a posted opposite journal entry while preserving the original posted entry; duplicate reversals are rejected.';
