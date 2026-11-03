create or replace function public.erp_register_checkbooks_batch(
  p_company_id uuid,
  p_books jsonb
)
returns jsonb
language plpgsql
security invoker
set search_path = public
as $function$
declare
  v_item jsonb;
  v_bank_id uuid;
  v_first bigint;
  v_last bigint;
  v_sheet_count integer;
  v_book_id uuid;
  v_books integer := 0;
  v_checks integer := 0;
begin
  if auth.uid() is null then
    raise exception 'يجب تسجيل الدخول أولاً';
  end if;
  if p_company_id is null
     or not public.erp_user_has_company_role(
       p_company_id,
       array['owner','admin','manager','accountant']::text[]
     ) then
    raise exception 'ليست لديك صلاحية تسجيل دفاتر الشيكات';
  end if;
  if jsonb_typeof(p_books) <> 'array'
     or jsonb_array_length(p_books) = 0 then
    raise exception 'أدخل دفتر شيكات واحدًا على الأقل';
  end if;

  perform c.id
  from public.erp_cashboxes c
  where c.company_id = p_company_id
    and c.id in (
      select distinct (item.value->>'bank_cashbox_id')::uuid
      from jsonb_array_elements(p_books) as item(value)
    )
  order by c.id
  for update;

  for v_item in select value from jsonb_array_elements(p_books)
  loop
    v_bank_id := nullif(v_item->>'bank_cashbox_id','')::uuid;
    v_first := nullif(v_item->>'first_check_number','')::bigint;
    if v_bank_id is null or v_first is null or v_first < 1 then
      raise exception 'الحساب البنكي وبداية الدفتر حقول إلزامية ويجب أن تكون البداية موجبة';
    end if;

    select c.checkbook_sheet_count into v_sheet_count
    from public.erp_cashboxes c
    where c.id = v_bank_id and c.company_id = p_company_id
      and c.is_bank_account = true and c.is_active = true
    for update;
    if not found then
      raise exception 'الحساب البنكي غير موجود أو غير نشط أو لا يتبع الشركة المحددة';
    end if;
    if v_sheet_count is null or v_sheet_count < 1 or v_sheet_count > 1000 then
      raise exception 'عدد أوراق دفتر الشيكات غير صحيح في بيانات الحساب البنكي';
    end if;
    if v_first > 9223372036854775807 - (v_sheet_count - 1) then
      raise exception 'نطاق أرقام الشيكات يتجاوز الحد المسموح';
    end if;

    v_last := v_first + v_sheet_count - 1;
    if exists (
      select 1 from public.erp_checkbooks b
      where b.company_id = p_company_id and b.bank_cashbox_id = v_bank_id
        and b.first_check_number <= v_last
        and b.first_check_number + b.sheet_count - 1 >= v_first
    ) then
      raise exception 'نطاق أرقام الدفتر يتداخل مع دفتر مسجل أو مسودة محفوظة على الحساب البنكي';
    end if;

    insert into public.erp_checkbooks(
      company_id, bank_cashbox_id, first_check_number, sheet_count, created_by
    ) values (p_company_id, v_bank_id, v_first, v_sheet_count, auth.uid())
    returning id into v_book_id;

    v_checks := v_checks + public.erp_register_checkbook(v_book_id);
    v_books := v_books + 1;
  end loop;

  return jsonb_build_object('books_registered', v_books, 'checks_created', v_checks);
end;
$function$;

revoke execute on function public.erp_register_checkbooks_batch(uuid,jsonb) from public, anon;
grant execute on function public.erp_register_checkbooks_batch(uuid,jsonb) to authenticated;

create or replace function public.erp_cancel_available_cheque(
  p_cheque_id uuid,
  p_reason text
)
returns void
language plpgsql
security invoker
set search_path = public
as $function$
declare
  v_cheque public.erp_cheques%rowtype;
  v_reason text;
begin
  if auth.uid() is null then
    raise exception 'يجب تسجيل الدخول أولاً';
  end if;
  select * into v_cheque from public.erp_cheques where id = p_cheque_id for update;
  if not found then raise exception 'الشيك غير موجود'; end if;
  if v_cheque.status <> 'available' then
    raise exception 'لا يمكن إلغاء شيك تم إصداره أو تسويته؛ الإلغاء متاح للشيكات غير المستخدمة فقط';
  end if;
  if not public.erp_user_has_company_role(
    v_cheque.company_id, array['owner','admin','manager','accountant']::text[]
  ) then
    raise exception 'ليست لديك صلاحية إلغاء الشيك';
  end if;
  v_reason := nullif(btrim(coalesce(p_reason,'')), '');
  if v_reason is null then raise exception 'سبب إلغاء الشيك مطلوب'; end if;

  update public.erp_cheques
  set status = 'cancelled',
      notes = concat_ws(E'\n', nullif(notes,''),
        'إلغاء الشيك: ' || v_reason || ' — ' || to_char(current_date,'DD-MM-YYYY')),
      updated_by = auth.uid(), updated_at = now()
  where id = p_cheque_id and company_id = v_cheque.company_id and status = 'available';
  if not found then
    raise exception 'تعذر إلغاء الشيك؛ ربما تغيرت حالته بواسطة مستخدم آخر';
  end if;
end;
$function$;

revoke execute on function public.erp_cancel_available_cheque(uuid,text) from public, anon;
grant execute on function public.erp_cancel_available_cheque(uuid,text) to authenticated;
