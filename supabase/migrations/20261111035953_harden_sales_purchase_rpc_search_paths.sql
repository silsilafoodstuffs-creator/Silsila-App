CREATE OR REPLACE FUNCTION public.erp_add_operational_document_line_v2(p_document_id uuid, p_kind text, p_item_id uuid, p_quantity numeric, p_unit_price numeric, p_discount numeric DEFAULT 0, p_tax numeric DEFAULT 0, p_unit_id uuid DEFAULT NULL::uuid)
 RETURNS uuid
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
 SET row_security TO 'off'
AS $function$
declare
  v_company uuid;
  v_status text;
  v_line_id uuid;
  v_subtotal numeric(14,2);
  v_discount numeric(14,2);
  v_tax numeric(14,2);
  v_unit_code text;
  v_factor numeric(14,6) := 1;
begin
  if p_kind not in ('purchase','sales') then raise exception 'نوع المستند غير مدعوم.'; end if;
  if p_item_id is null or p_quantity is null or p_quantity <= 0
     or p_unit_price is null or p_unit_price < 0
     or coalesce(p_discount,0) < 0 or coalesce(p_tax,0) < 0
     or coalesce(p_discount,0) > p_quantity * p_unit_price then
    raise exception 'راجع الصنف والكمية والسعر والخصم والضريبة.';
  end if;

  if p_kind = 'purchase' then
    select company_id, status into v_company, v_status
    from public.erp_purchase_documents where id = p_document_id for update;
  else
    select company_id, status into v_company, v_status
    from public.erp_sales_documents where id = p_document_id for update;
  end if;
  if v_company is null then raise exception 'المستند غير موجود.'; end if;
  if not public.erp_user_has_company_role(v_company, array['owner','admin','manager','operator','accountant']::text[]) then
    raise exception 'ليست لديك صلاحية تعديل المستند.';
  end if;
  if v_status <> 'draft' then raise exception 'يمكن تعديل المسودة فقط.'; end if;
  if not exists (
    select 1 from public.erp_items i
    where i.id = p_item_id and i.company_id = v_company and i.is_active
  ) then raise exception 'الصنف غير نشط أو لا يتبع الشركة.'; end if;

  if p_unit_id is not null then
    select u.unit_code, u.conversion_factor into v_unit_code, v_factor
    from public.erp_item_units u
    where u.id = p_unit_id and u.item_id = p_item_id
      and u.company_id = v_company and u.is_active and u.is_selectable;
    if not found then raise exception 'وحدة القياس غير نشطة أو لا تتبع الصنف.'; end if;
  else
    select i.base_unit into v_unit_code from public.erp_items i where i.id = p_item_id;
    v_factor := 1;
  end if;

  if p_kind = 'purchase' then
    insert into public.erp_purchase_lines(
      document_id, item_id, quantity, unit_price, discount_amount, tax_amount,
      line_total, unit_id, unit_code, conversion_factor, base_quantity
    ) values (
      p_document_id, p_item_id, p_quantity, p_unit_price, coalesce(p_discount,0),
      coalesce(p_tax,0), round(p_quantity * p_unit_price,2) - coalesce(p_discount,0) + coalesce(p_tax,0),
      p_unit_id, coalesce(v_unit_code,'وحدة'), v_factor, p_quantity * v_factor
    ) returning id into v_line_id;

    select coalesce(sum(quantity * unit_price),0), coalesce(sum(discount_amount),0), coalesce(sum(tax_amount),0)
      into v_subtotal, v_discount, v_tax
    from public.erp_purchase_lines where document_id = p_document_id;
    update public.erp_purchase_documents set subtotal = v_subtotal, discount_total = v_discount,
      tax_total = v_tax, grand_total = v_subtotal - v_discount + v_tax, updated_at = now()
    where id = p_document_id and status = 'draft';
  else
    insert into public.erp_sales_lines(
      document_id, item_id, quantity, unit_price, discount_amount, tax_amount,
      line_total, unit_id, unit_code, conversion_factor, base_quantity
    ) values (
      p_document_id, p_item_id, p_quantity, p_unit_price, coalesce(p_discount,0),
      coalesce(p_tax,0), round(p_quantity * p_unit_price,2) - coalesce(p_discount,0) + coalesce(p_tax,0),
      p_unit_id, coalesce(v_unit_code,'وحدة'), v_factor, p_quantity * v_factor
    ) returning id into v_line_id;

    select coalesce(sum(quantity * unit_price),0), coalesce(sum(discount_amount),0), coalesce(sum(tax_amount),0)
      into v_subtotal, v_discount, v_tax
    from public.erp_sales_lines where document_id = p_document_id;
    update public.erp_sales_documents set subtotal = v_subtotal, discount_total = v_discount,
      tax_total = v_tax, grand_total = v_subtotal - v_discount + v_tax, updated_at = now()
    where id = p_document_id and status = 'draft';
  end if;
  return v_line_id;
end;
$function$
;

CREATE OR REPLACE FUNCTION public.erp_add_operational_document_lines_v2(p_document_id uuid, p_kind text, p_lines jsonb)
 RETURNS integer
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
 SET row_security TO 'off'
AS $function$
declare
  v_line jsonb;
  v_line_id uuid;
  v_count integer := 0;
begin
  if p_lines is null or jsonb_typeof(p_lines) <> 'array' or jsonb_array_length(p_lines) = 0 then
    raise exception 'اختر صنفًا واحدًا على الأقل.';
  end if;
  if jsonb_array_length(p_lines) > 500 then
    raise exception 'لا يمكن إضافة أكثر من 500 سطر دفعة واحدة.';
  end if;
  for v_line in select value from jsonb_array_elements(p_lines)
  loop
    v_line_id := public.erp_add_operational_document_line_v2(
      p_document_id, p_kind,
      (v_line->>'item_id')::uuid,
      (v_line->>'quantity')::numeric,
      (v_line->>'unit_price')::numeric,
      coalesce((v_line->>'discount')::numeric, 0),
      coalesce((v_line->>'tax')::numeric, 0),
      nullif(v_line->>'unit_id','')::uuid
    );
    if p_kind='sales' and nullif(v_line->>'campaign_item_id','') is not null then
      update public.erp_sales_lines set campaign_item_id=(v_line->>'campaign_item_id')::uuid where id=v_line_id and document_id=p_document_id;
      if not found then raise exception 'تعذر ربط بند العرض بسطر الفاتورة.'; end if;
    end if;
    if p_kind='sales' and nullif(v_line->>'shortage_id','') is not null then
      update public.erp_sales_lines set shortage_id=(v_line->>'shortage_id')::uuid where id=v_line_id and document_id=p_document_id;
      if not found then raise exception 'تعذر ربط نقص العميل بسطر الفاتورة.'; end if;
    end if;
    v_count := v_count + 1;
  end loop;
  return v_count;
end;
$function$
;

CREATE OR REPLACE FUNCTION public.erp_post_sales_document(p_document_id uuid)
 RETURNS uuid
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
 SET row_security TO 'off'
AS $function$
declare
  v_doc public.erp_sales_documents%rowtype;
  v_line record;
  v_count integer := 0;
  v_subtotal numeric(16,2);
  v_discount numeric(16,2);
  v_tax numeric(16,2);
  v_line_total numeric(16,2);
  v_movement_type text;
begin
  select * into v_doc from public.erp_sales_documents where id = p_document_id for update;
  if not found then raise exception 'مستند المبيعات غير موجود'; end if;
  if not public.erp_user_has_company_role(v_doc.company_id, array['owner','admin','manager','accountant']::text[]) then
    raise exception 'ليست لديك صلاحية ترحيل مستند المبيعات';
  end if;
  if v_doc.status <> 'draft' then raise exception 'يمكن ترحيل المسودات فقط؛ الاعتماد يحتاج مسارًا مخصصًا'; end if;
  if v_doc.document_type not in ('delivery','invoice','return') then
    raise exception 'نوع المستند لا ينشئ حركة مخزنية؛ لا يمكن ترحيله كصرف';
  end if;
  if v_doc.warehouse_id is null then raise exception 'اختر مخزنًا للمستند قبل الترحيل'; end if;
  if not exists (select 1 from public.erp_warehouses w where w.id = v_doc.warehouse_id and w.company_id = v_doc.company_id and w.is_active) then
    raise exception 'المخزن غير نشط أو لا يتبع الشركة'; end if;
  select count(*)::integer, coalesce(sum(round(l.quantity * l.unit_price,2)),0),
    coalesce(sum(l.discount_amount),0), coalesce(sum(l.tax_amount),0), coalesce(sum(l.line_total),0)
    into v_count, v_subtotal, v_discount, v_tax, v_line_total
  from public.erp_sales_lines l where l.document_id = v_doc.id;
  if v_count = 0 then raise exception 'لا يمكن ترحيل مستند مبيعات بلا بنود'; end if;
  if v_doc.subtotal <> v_subtotal or v_doc.discount_total <> v_discount
     or v_doc.tax_total <> v_tax or v_doc.grand_total <> v_line_total
     or v_doc.grand_total <> v_subtotal - v_discount + v_tax then
    raise exception 'إجماليات مستند المبيعات لا تطابق تفاصيل البنود؛ أعد حساب المستند قبل الترحيل';
  end if;

  v_movement_type := case when v_doc.document_type = 'return' then 'customer_return' else 'sales_issue' end;
  for v_line in
    select l.* from public.erp_sales_lines l where l.document_id = v_doc.id order by l.created_at, l.id
  loop
    perform public.erp_record_inventory_movement(
      v_doc.company_id, v_doc.warehouse_id, v_line.item_id, v_movement_type,
      coalesce(v_line.base_quantity, v_line.quantity),
      greatest(round(v_line.unit_price / coalesce(nullif(v_line.conversion_factor,0),1),4),0),
      v_doc.branch_id, case when v_doc.document_date = current_date then now() else (v_doc.document_date + time '23:59:59')::timestamptz end,
      'sales_document', v_doc.id, v_line.batch_number, v_line.expiry_date,
      'مستند مبيعات ' || v_doc.document_number
    );
  end loop;

  update public.erp_sales_documents set status = 'posted', updated_at = now() where id = v_doc.id;
  return v_doc.id;
end;
$function$
;

CREATE OR REPLACE FUNCTION public.erp_post_purchase_document(p_document_id uuid)
 RETURNS uuid
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
 SET row_security TO 'off'
AS $function$
declare
  v_doc public.erp_purchase_documents%rowtype;
  v_line record;
  v_count integer := 0;
  v_subtotal numeric(16,2);
  v_discount numeric(16,2);
  v_tax numeric(16,2);
  v_line_total numeric(16,2);
  v_movement_type text;
begin
  select * into v_doc from public.erp_purchase_documents where id = p_document_id for update;
  if not found then raise exception 'مستند المشتريات غير موجود'; end if;
  if not public.erp_user_has_company_role(v_doc.company_id, array['owner','admin','manager','accountant']::text[]) then
    raise exception 'ليست لديك صلاحية ترحيل مستند المشتريات';
  end if;
  if v_doc.status <> 'draft' then raise exception 'يمكن ترحيل المسودات فقط؛ الاعتماد يحتاج مسارًا مخصصًا'; end if;
  if v_doc.document_type not in ('receipt','invoice','return') then
    raise exception 'نوع المستند لا ينشئ حركة مخزنية؛ لا يمكن ترحيله كاستلام';
  end if;
  if v_doc.warehouse_id is null then raise exception 'اختر مخزنًا للمستند قبل الترحيل'; end if;
  if not exists (select 1 from public.erp_warehouses w where w.id = v_doc.warehouse_id and w.company_id = v_doc.company_id and w.is_active) then
    raise exception 'المخزن غير نشط أو لا يتبع الشركة'; end if;
  select count(*)::integer, coalesce(sum(round(l.quantity * l.unit_price,2)),0),
    coalesce(sum(l.discount_amount),0), coalesce(sum(l.tax_amount),0), coalesce(sum(l.line_total),0)
    into v_count, v_subtotal, v_discount, v_tax, v_line_total
  from public.erp_purchase_lines l where l.document_id = v_doc.id;
  if v_count = 0 then raise exception 'لا يمكن ترحيل مستند مشتريات بلا بنود'; end if;
  if v_doc.subtotal <> v_subtotal or v_doc.discount_total <> v_discount
     or v_doc.tax_total <> v_tax or v_doc.grand_total <> v_line_total
     or v_doc.grand_total <> v_subtotal - v_discount + v_tax then
    raise exception 'إجماليات مستند المشتريات لا تطابق تفاصيل البنود؛ أعد حساب المستند قبل الترحيل';
  end if;

  v_movement_type := case when v_doc.document_type = 'return' then 'supplier_return' else 'purchase_receipt' end;
  for v_line in
    select l.* from public.erp_purchase_lines l where l.document_id = v_doc.id order by l.created_at, l.id
  loop
    perform public.erp_record_inventory_movement(
      v_doc.company_id, v_doc.warehouse_id, v_line.item_id, v_movement_type,
      coalesce(v_line.base_quantity, v_line.quantity),
      greatest(round((round(v_line.quantity * v_line.unit_price, 2) - v_line.discount_amount) / coalesce(nullif(v_line.base_quantity,0),v_line.quantity),4),0),
      v_doc.branch_id, case when v_doc.document_date = current_date then now() else (v_doc.document_date + time '23:59:59')::timestamptz end,
      'purchase_document', v_doc.id, v_line.batch_number, v_line.expiry_date,
      'مستند مشتريات ' || v_doc.document_number
    );
  end loop;

  update public.erp_purchase_documents set status = 'posted', updated_at = now() where id = v_doc.id;
  return v_doc.id;
end;
$function$
;
revoke all on function public.erp_add_operational_document_line_v2(uuid,text,uuid,numeric,numeric,numeric,numeric,uuid) from public;
revoke all on function public.erp_add_operational_document_line_v2(uuid,text,uuid,numeric,numeric,numeric,numeric,uuid) from anon;
grant execute on function public.erp_add_operational_document_line_v2(uuid,text,uuid,numeric,numeric,numeric,numeric,uuid) to authenticated;

revoke all on function public.erp_add_operational_document_lines_v2(uuid,text,jsonb) from public;
revoke all on function public.erp_add_operational_document_lines_v2(uuid,text,jsonb) from anon;
grant execute on function public.erp_add_operational_document_lines_v2(uuid,text,jsonb) to authenticated;

revoke all on function public.erp_post_sales_document(uuid) from public;
revoke all on function public.erp_post_sales_document(uuid) from anon;
grant execute on function public.erp_post_sales_document(uuid) to authenticated;

revoke all on function public.erp_post_purchase_document(uuid) from public;
revoke all on function public.erp_post_purchase_document(uuid) from anon;
grant execute on function public.erp_post_purchase_document(uuid) to authenticated;
