-- Journal-entry transaction functions for Silsila ERP.
-- Apply after erp_schema.sql. RLS remains authoritative; no policies are opened here.

create or replace function public.erp_save_journal_draft(
  p_company_id uuid,
  p_entry_date date,
  p_description text,
  p_lines jsonb,
  p_entry_id uuid default null
)
returns uuid
language plpgsql
security invoker
set search_path = public
as $$
declare
  v_entry_id uuid;
  v_line jsonb;
  v_account_id uuid;
  v_debit numeric(14,2);
  v_credit numeric(14,2);
  v_count integer := 0;
  v_total_debit numeric(18,2) := 0;
  v_total_credit numeric(18,2) := 0;
  v_account record;
begin
  if p_company_id is null or p_entry_date is null then
    raise exception 'الشركة وتاريخ القيد مطلوبان';
  end if;
  if nullif(trim(p_description), '') is null then
    raise exception 'بيان القيد مطلوب';
  end if;
  if p_lines is null or jsonb_typeof(p_lines) is distinct from 'array' then
    raise exception 'سطور القيد يجب أن تُرسل في صورة قائمة';
  end if;
  if jsonb_array_length(p_lines) < 2 then
    raise exception 'يجب إدخال سطرين على الأقل في القيد';
  end if;

  if exists (
    select 1 from public.erp_fiscal_periods fp
    where fp.company_id = p_company_id
      and p_entry_date between fp.starts_on and fp.ends_on
      and fp.status = 'closed'
  ) then
    raise exception 'لا يمكن حفظ قيد داخل فترة مالية مغلقة';
  end if;

  if p_entry_id is not null then
    update public.erp_journal_entries
       set entry_date = p_entry_date,
           description = trim(p_description),
           fiscal_period_id = (
             select fp.id from public.erp_fiscal_periods fp
             where fp.company_id = p_company_id
               and p_entry_date between fp.starts_on and fp.ends_on
             order by fp.starts_on desc limit 1
           ),
           updated_at = now()
     where id = p_entry_id
       and company_id = p_company_id
       and status = 'draft';
    if not found then
      raise exception 'القيد غير موجود أو لم يعد مسودة قابلة للتعديل';
    end if;
    v_entry_id := p_entry_id;
    delete from public.erp_journal_lines where entry_id = v_entry_id;
  else
    insert into public.erp_journal_entries(
      company_id, fiscal_period_id, entry_date, description, status, source_type, created_by
    ) values (
      p_company_id,
      (select fp.id from public.erp_fiscal_periods fp
       where fp.company_id = p_company_id
         and p_entry_date between fp.starts_on and fp.ends_on
       order by fp.starts_on desc limit 1),
      p_entry_date, trim(p_description), 'draft', 'manual', auth.uid()
    ) returning id into v_entry_id;
  end if;

  for v_line in select value from jsonb_array_elements(p_lines)
  loop
    v_count := v_count + 1;
    v_account_id := nullif(v_line->>'account_id','')::uuid;
    v_debit := coalesce(nullif(v_line->>'debit','')::numeric, 0);
    v_credit := coalesce(nullif(v_line->>'credit','')::numeric, 0);
    if v_account_id is null or v_debit < 0 or v_credit < 0
       or not ((v_debit > 0 and v_credit = 0) or (v_credit > 0 and v_debit = 0)) then
      raise exception 'راجع سطر القيد رقم %: اختر حسابًا وأدخل مدينًا أو دائنًا فقط', v_count;
    end if;
    select a.id, a.is_active, a.is_postable
      into v_account
    from public.erp_accounts a
    where a.id = v_account_id and a.company_id = p_company_id;
    if not found then
      raise exception 'أحد حسابات القيد غير موجود داخل الشركة المحددة';
    end if;
    if not v_account.is_active or not v_account.is_postable then
      raise exception 'يجب أن يكون حساب القيد نشطًا وقابلًا للترحيل';
    end if;
    insert into public.erp_journal_lines(
      entry_id, account_id, description, debit, credit
    ) values (
      v_entry_id, v_account_id, nullif(trim(v_line->>'description'), ''),
      v_debit, v_credit
    );
    v_total_debit := v_total_debit + v_debit;
    v_total_credit := v_total_credit + v_credit;
  end loop;

  return v_entry_id;
end;
$$;

create or replace function public.erp_post_journal_entry(p_entry_id uuid)
returns uuid
language plpgsql
security invoker
set search_path = public
as $$
declare
  v_entry public.erp_journal_entries%rowtype;
  v_count integer;
  v_debit numeric(18,2);
  v_credit numeric(18,2);
begin
  select * into v_entry
  from public.erp_journal_entries
  where id = p_entry_id
  for update;

  if not found then
    raise exception 'القيد غير موجود أو غير متاح';
  end if;
  if v_entry.status <> 'draft' then
    raise exception 'يمكن ترحيل المسودات فقط';
  end if;

  if exists (
    select 1 from public.erp_fiscal_periods fp
    where fp.company_id = v_entry.company_id
      and v_entry.entry_date between fp.starts_on and fp.ends_on
      and fp.status = 'closed'
  ) then
    raise exception 'لا يمكن ترحيل قيد داخل فترة مالية مغلقة';
  end if;

  select count(*), coalesce(sum(debit),0), coalesce(sum(credit),0)
    into v_count, v_debit, v_credit
  from public.erp_journal_lines
  where entry_id = p_entry_id;

  if v_count < 2 then
    raise exception 'لا يمكن ترحيل قيد يحتوي على أقل من سطرين';
  end if;
  if v_debit <= 0 or v_debit <> v_credit then
    raise exception 'القيد غير متوازن؛ يجب أن يتساوى إجمالي المدين والدائن';
  end if;

  if exists (
    select 1
    from public.erp_journal_lines jl
    join public.erp_accounts a on a.id = jl.account_id
    where jl.entry_id = p_entry_id
      and (a.company_id <> v_entry.company_id or not a.is_active or not a.is_postable)
  ) then
    raise exception 'يوجد حساب غير صالح أو غير نشط في القيد';
  end if;

  update public.erp_journal_entries
     set status = 'posted',
         posted_by = auth.uid(),
         posted_at = now(),
         updated_at = now()
   where id = p_entry_id;

  return p_entry_id;
end;
$$;

revoke all on function public.erp_save_journal_draft(uuid,date,text,jsonb,uuid) from public, anon;
revoke all on function public.erp_post_journal_entry(uuid) from public, anon;
grant execute on function public.erp_save_journal_draft(uuid,date,text,jsonb,uuid) to authenticated;
grant execute on function public.erp_post_journal_entry(uuid) to authenticated;

comment on function public.erp_save_journal_draft(uuid,date,text,jsonb,uuid) is
  'Atomically creates or replaces journal draft lines; validates account company, active/postable state, and open period.';
comment on function public.erp_post_journal_entry(uuid) is
  'Posts a draft only after server-side balance, line-count, account, and fiscal-period validation.';
