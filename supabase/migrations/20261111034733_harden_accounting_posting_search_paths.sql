CREATE OR REPLACE FUNCTION public.erp_post_asset_disposal(p_company_id uuid, p_disposal_id uuid)
 RETURNS uuid
 LANGUAGE plpgsql
 SET search_path TO ''
AS $function$
declare v_disposal public.erp_asset_disposals%rowtype; v_asset public.erp_fixed_assets%rowtype;
 v_lines jsonb:='[]'::jsonb; v_entry_id uuid; v_book numeric(18,3); v_gain numeric(18,3); v_loss numeric(18,3);
begin
 if auth.uid() is null then raise exception 'يلزم تسجيل الدخول'; end if;
 if not (public.erp_user_has_company_role(p_company_id,array['owner','admin','manager','accountant'])
  or exists(select 1 from public.erp_company_member_profiles p where p.company_id=p_company_id and p.user_id=(select auth.uid()))) then
  raise exception 'لا تملك صلاحية ترحيل استبعاد الأصول';
 end if;
 select * into v_disposal from public.erp_asset_disposals d where d.id=p_disposal_id and d.company_id=p_company_id for update;
 if not found then raise exception 'عملية استبعاد الأصل غير موجودة'; end if;
 if v_disposal.status='posted' and v_disposal.journal_entry_id is not null then return v_disposal.journal_entry_id; end if;
 if v_disposal.status not in ('approved','draft') then raise exception 'حالة الاستبعاد لا تسمح بالترحيل'; end if;
 select * into v_asset from public.erp_fixed_assets a where a.id=v_disposal.asset_id and a.company_id=p_company_id for update;
 if not found then raise exception 'الأصل المرتبط بالاستبعاد غير موجود'; end if;
 if v_asset.status='disposed' then raise exception 'الأصل مستبعد بالفعل'; end if;
 v_book:=greatest(v_asset.acquisition_cost-v_asset.accumulated_depreciation,0);
 if abs(v_disposal.book_value-v_book)>0.01 then raise exception 'القيمة الدفترية المسجلة لا تطابق القيمة الحالية للأصل؛ حدّث عملية الاستبعاد أولاً'; end if;
 v_gain:=greatest(v_disposal.proceeds-v_book,0);v_loss:=greatest(v_book-v_disposal.proceeds,0);
 if v_asset.asset_account_id is null then raise exception 'اربط حساب الأصل قبل الاستبعاد'; end if;
 if v_asset.accumulated_depreciation>0 and v_asset.accumulated_account_id is null then raise exception 'اربط حساب مجمع الإهلاك قبل الاستبعاد'; end if;
 if v_disposal.proceeds>0 and v_disposal.cash_account_id is null then raise exception 'حدد حساب مقابل البيع أو النقدية'; end if;
 if (v_gain>0 or v_loss>0) and v_disposal.gain_loss_account_id is null then raise exception 'حدد حساب أرباح أو خسائر استبعاد الأصول'; end if;
 if v_asset.accumulated_depreciation>0 then
  v_lines:=v_lines||jsonb_build_array(jsonb_build_object('account_id',v_asset.accumulated_account_id,'debit',v_asset.accumulated_depreciation,'credit',0,'description','إقفال مجمع إهلاك الأصل '||v_asset.asset_code));
 end if;
 if v_disposal.proceeds>0 then
  v_lines:=v_lines||jsonb_build_array(jsonb_build_object('account_id',v_disposal.cash_account_id,'debit',v_disposal.proceeds,'credit',0,'description','متحصلات استبعاد الأصل '||v_asset.asset_code));
 end if;
 v_lines:=v_lines||jsonb_build_array(jsonb_build_object('account_id',v_asset.asset_account_id,'debit',0,'credit',v_asset.acquisition_cost,'description','إخراج تكلفة الأصل '||v_asset.asset_code));
 if v_gain>0 then
  v_lines:=v_lines||jsonb_build_array(jsonb_build_object('account_id',v_disposal.gain_loss_account_id,'debit',0,'credit',v_gain,'description','ربح استبعاد الأصل '||v_asset.asset_code));
 end if;
 if v_loss>0 then
  v_lines:=v_lines||jsonb_build_array(jsonb_build_object('account_id',v_disposal.gain_loss_account_id,'debit',v_loss,'credit',0,'description','خسارة استبعاد الأصل '||v_asset.asset_code));
 end if;
 v_entry_id:=public.erp_save_journal_draft(p_company_id,v_disposal.disposal_date,'قيد استبعاد أصل - '||v_disposal.disposal_code,v_lines,null);
 perform public.erp_post_journal_entry(v_entry_id);
 update public.erp_asset_disposals set status='posted',journal_entry_id=v_entry_id where id=p_disposal_id and company_id=p_company_id;
 update public.erp_fixed_assets set status='disposed',updated_at=now() where id=v_asset.id and company_id=p_company_id;
 return v_entry_id;
end;
$function$
;

CREATE OR REPLACE FUNCTION public.erp_save_journal_draft(p_company_id uuid, p_entry_date date, p_description text, p_lines jsonb, p_entry_id uuid DEFAULT NULL::uuid)
 RETURNS uuid
 LANGUAGE plpgsql
 SET search_path TO ''
AS $function$
declare
  v_entry_id uuid;
  v_line jsonb;
  v_account_id uuid;
  v_party_id uuid;
  v_branch_id uuid;
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
    v_party_id := nullif(v_line->>'party_id','')::uuid;
    v_branch_id := nullif(v_line->>'branch_id','')::uuid;
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
    if v_party_id is not null and not exists (
      select 1 from public.erp_parties p where p.id = v_party_id and p.company_id = p_company_id and p.is_active
    ) then raise exception 'الطرف في سطر القيد غير نشط أو لا يتبع الشركة'; end if;
    if v_branch_id is not null and not exists (
      select 1 from public.erp_branches b where b.id = v_branch_id and b.company_id = p_company_id and b.is_active
    ) then raise exception 'الفرع في سطر القيد غير نشط أو لا يتبع الشركة'; end if;
    insert into public.erp_journal_lines(
      entry_id, account_id, description, debit, credit, party_id, branch_id
    ) values (
      v_entry_id, v_account_id, nullif(trim(v_line->>'description'), ''),
      v_debit, v_credit, v_party_id, v_branch_id
    );
    v_total_debit := v_total_debit + v_debit;
    v_total_credit := v_total_credit + v_credit;
  end loop;

  return v_entry_id;
end;
$function$
;

CREATE OR REPLACE FUNCTION public.erp_post_journal_entry(p_entry_id uuid)
 RETURNS uuid
 LANGUAGE plpgsql
 SET search_path TO ''
AS $function$
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
$function$
;

revoke all on function public.erp_post_asset_disposal(uuid,uuid) from public;
revoke all on function public.erp_post_asset_disposal(uuid,uuid) from anon;
grant execute on function public.erp_post_asset_disposal(uuid,uuid) to authenticated;

revoke all on function public.erp_save_journal_draft(uuid,date,text,jsonb,uuid) from public;
revoke all on function public.erp_save_journal_draft(uuid,date,text,jsonb,uuid) from anon;
grant execute on function public.erp_save_journal_draft(uuid,date,text,jsonb,uuid) to authenticated;

revoke all on function public.erp_post_journal_entry(uuid) from public;
revoke all on function public.erp_post_journal_entry(uuid) from anon;
grant execute on function public.erp_post_journal_entry(uuid) to authenticated;
