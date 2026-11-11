CREATE OR REPLACE FUNCTION public.erp_save_sales_fulfillment_batch(p_company_id uuid, p_kind text, p_rows jsonb)
 RETURNS jsonb
 LANGUAGE plpgsql
 SET search_path TO ''
AS $function$
declare
  v_row record;
  v_invoice public.erp_sales_documents%rowtype;
  v_party public.erp_parties%rowtype;
  v_existing public.erp_sales_fulfillment_documents%rowtype;
  v_user_id uuid;
  v_customer_name text;
  v_area_name text;
  v_row_count integer := 0;
  v_saved_count integer := 0;
  v_ids uuid[] := array[]::uuid[];
  v_id uuid;
  v_source_count integer := 0;
  v_allowed boolean := false;
begin
  v_user_id:=(select auth.uid());
  if v_user_id is null then
    raise exception 'يلزم تسجيل الدخول' using errcode='28000';
  end if;
  if p_company_id is null then
    raise exception 'الشركة مطلوبة' using errcode='22023';
  end if;
  if p_kind not in ('preparation','delivery') then
    raise exception 'نوع إذن التجهيز أو التسليم غير صحيح' using errcode='22023';
  end if;
  if p_rows is null or jsonb_typeof(p_rows)<>'array' then
    raise exception 'قائمة الأذون غير صحيحة' using errcode='22023';
  end if;
  v_row_count:=jsonb_array_length(p_rows);
  if v_row_count=0 or v_row_count>500 then
    raise exception 'عدد الأذون يجب أن يكون من 1 إلى 500' using errcode='22023';
  end if;

  if not exists (
    select 1 from public.erp_company_members m
    where m.company_id=p_company_id
      and m.user_id=v_user_id
      and m.is_active=true
  ) then
    raise exception 'لا تملك عضوية نشطة في الشركة المحددة' using errcode='42501';
  end if;

  if exists (
    select x.invoice_id
    from jsonb_to_recordset(p_rows) as x(
      invoice_id uuid,
      source_fulfillment_ids uuid[],
      source_mode text,
      weight_kg numeric,
      load_kg numeric
    )
    group by x.invoice_id
    having x.invoice_id is null or count(*)>1
  ) then
    raise exception 'فاتورة مكررة أو معرف فاتورة غير صحيح في دفعة الأذون' using errcode='23505';
  end if;

  if exists (
    select 1
    from jsonb_to_recordset(p_rows) as x(
      invoice_id uuid,
      source_fulfillment_ids uuid[],
      source_mode text,
      weight_kg numeric,
      load_kg numeric
    )
    where x.invoice_id is null
       or x.source_mode is null
       or x.weight_kg is null or x.weight_kg<0
       or x.load_kg is null or x.load_kg<0
       or coalesce(cardinality(x.source_fulfillment_ids),0)>100
       or (
         p_kind='preparation'
         and (x.source_mode<>'invoice' or cardinality(coalesce(x.source_fulfillment_ids,array[]::uuid[]))<>0)
       )
       or (
         p_kind='delivery'
         and x.source_mode not in ('preparation','direct')
       )
       or (
         p_kind='delivery' and x.source_mode='direct'
         and cardinality(coalesce(x.source_fulfillment_ids,array[]::uuid[]))<>0
       )
       or (
         p_kind='delivery' and x.source_mode='preparation'
         and cardinality(coalesce(x.source_fulfillment_ids,array[]::uuid[]))=0
       )
  ) then
    raise exception 'نوع المصدر أو الوزن أو الحمولة أو روابط أذون التجهيز غير صالحة' using errcode='22023';
  end if;

  if exists (
    select 1
    from jsonb_to_recordset(p_rows) as x(
      invoice_id uuid,
      source_fulfillment_ids uuid[],
      source_mode text,
      weight_kg numeric,
      load_kg numeric
    )
    cross join lateral unnest(coalesce(x.source_fulfillment_ids,array[]::uuid[])) as ids(id)
    group by x.invoice_id,ids.id
    having count(*)>1
  ) then
    raise exception 'يوجد إذن تجهيز مكرر في روابط أحد أذون التسليم' using errcode='23505';
  end if;

  for v_row in
    select x.invoice_id,
           coalesce(x.source_fulfillment_ids,array[]::uuid[]) as source_fulfillment_ids,
           x.source_mode,x.weight_kg,x.load_kg
    from jsonb_to_recordset(p_rows) as x(
      invoice_id uuid,
      source_fulfillment_ids uuid[],
      source_mode text,
      weight_kg numeric,
      load_kg numeric
    )
    order by x.invoice_id
  loop
    select d.* into v_invoice
    from public.erp_sales_documents d
    where d.id=v_row.invoice_id
      and d.company_id=p_company_id
      and d.document_type='invoice'
      and d.status in ('draft','approved','posted')
    for share;
    if not found then
      raise exception 'إحدى فواتير البيع غير موجودة أو غير متاحة أو لا تتبع الشركة' using errcode='23503';
    end if;

    select p.* into v_party
    from public.erp_parties p
    where p.id=v_invoice.customer_id
      and p.company_id=p_company_id;
    if not found then
      raise exception 'العميل المرتبط بإحدى الفواتير لا يتبع الشركة المحددة' using errcode='23503';
    end if;

    v_customer_name:=v_party.party_name;
    v_area_name:=concat_ws(
      ' / ',
      nullif(btrim(v_party.area),''),
      nullif(btrim(v_party.district),''),
      nullif(btrim(v_party.governorate),'')
    );

    if p_kind='delivery' and v_row.source_mode='preparation' then
      select count(*) into v_source_count
      from unnest(v_row.source_fulfillment_ids) as ids(id)
      join public.erp_sales_fulfillment_documents p
        on p.id=ids.id
       and p.company_id=p_company_id
       and p.kind='preparation'
       and p.invoice_id=v_row.invoice_id
       and p.status in ('draft','completed');
      if v_source_count<>cardinality(v_row.source_fulfillment_ids) then
        raise exception 'أحد أذون التجهيز لا يخص الفاتورة المحددة أو غير متاح' using errcode='23503';
      end if;
    elsif p_kind='delivery' and v_row.source_mode='direct' then
      select
        public.erp_user_has_company_role(p_company_id,array['owner','admin']::text[])
        or exists (
          select 1 from public.erp_user_permissions up
          where up.company_id=p_company_id
            and up.user_id=v_user_id
            and up.menu_key in (
              'مبيعات::حركات::إذن التسليم',
              'المبيعات والعملاء::حركات::إذن التسليم'
            )
            and up.allow_access=true
            and up.can_edit=true
        )
      into v_allowed;
      if not coalesce(v_allowed,false) then
        raise exception 'التحميل بدون تجهيز يتطلب صلاحية تعديل إذن التسليم' using errcode='42501';
      end if;
    end if;

    insert into public.erp_sales_fulfillment_documents(
      company_id,kind,invoice_id,source_fulfillment_ids,source_mode,
      customer_name,area_name,invoice_amount,weight_kg,load_kg,
      status,created_by
    )
    values(
      p_company_id,p_kind,v_invoice.id,v_row.source_fulfillment_ids,v_row.source_mode,
      v_customer_name,coalesce(v_area_name,''),v_invoice.grand_total,
      v_row.weight_kg,v_row.load_kg,'draft',v_user_id
    )
    on conflict(company_id,kind,invoice_id)
    do update set
      source_fulfillment_ids=excluded.source_fulfillment_ids,
      source_mode=excluded.source_mode,
      customer_name=excluded.customer_name,
      area_name=excluded.area_name,
      invoice_amount=excluded.invoice_amount,
      weight_kg=excluded.weight_kg,
      load_kg=excluded.load_kg,
      updated_at=now()
    where public.erp_sales_fulfillment_documents.status='draft'
    returning id into v_id;

    if v_id is null then
      raise exception 'يوجد إذن مكتمل أو ملغي لا يمكن استبداله بمسودة جديدة؛ راجع الإذن أولًا' using errcode='23514';
    end if;

    v_ids:=array_append(v_ids,v_id);
    v_saved_count:=v_saved_count+1;
  end loop;

  return jsonb_build_object(
    'saved_count',v_saved_count,
    'document_ids',to_jsonb(v_ids),
    'kind',p_kind
  );
end;
$function$
;
revoke all on function public.erp_save_sales_fulfillment_batch(uuid,text,jsonb) from public;
revoke all on function public.erp_save_sales_fulfillment_batch(uuid,text,jsonb) from anon;
grant execute on function public.erp_save_sales_fulfillment_batch(uuid,text,jsonb) to authenticated;
