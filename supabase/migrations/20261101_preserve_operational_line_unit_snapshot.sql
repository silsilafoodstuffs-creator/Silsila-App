-- Preserve the selected unit and its base-unit quantity on operational document lines.
-- This keeps historical line interpretation stable even if item-unit definitions change later.
create or replace function public.erp_add_operational_document_line_v2(
  p_document_id uuid,
  p_kind text,
  p_item_id uuid,
  p_quantity numeric,
  p_unit_price numeric,
  p_discount numeric default 0,
  p_tax numeric default 0,
  p_unit_id uuid default null
)
returns uuid
language plpgsql
security definer
set search_path to 'public'
set row_security to 'off'
as $function$
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
$function$;
