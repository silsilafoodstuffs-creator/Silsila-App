-- Link sales invoice lines to customer shortages and fulfill them when the invoice is posted.
alter table public.erp_sales_lines
  add column if not exists shortage_id uuid references public.erp_customer_shortages(id) on delete set null;
create index if not exists erp_sales_lines_shortage_idx
  on public.erp_sales_lines(shortage_id) where shortage_id is not null;

create or replace function public.erp_validate_customer_shortage_sales_line()
returns trigger
language plpgsql
security definer
set search_path = public
set row_security = off
as $$
declare
  v_doc public.erp_sales_documents%rowtype;
  v_shortage public.erp_customer_shortages%rowtype;
begin
  if new.shortage_id is null then return new; end if;
  select * into v_doc from public.erp_sales_documents where id=new.document_id;
  if not found or v_doc.status<>'draft' then raise exception 'يمكن ربط النقص بمسودة مبيعات فقط.'; end if;
  select * into v_shortage from public.erp_customer_shortages where id=new.shortage_id for update;
  if not found or v_shortage.company_id<>v_doc.company_id or v_shortage.customer_id is distinct from v_doc.customer_id
     or v_shortage.item_id<>new.item_id or v_shortage.status not in ('open','partial') then
    raise exception 'النقص المحدد لا يطابق العميل والصنف أو لم يعد مفتوحًا.';
  end if;
  if coalesce(new.base_quantity,new.quantity) > (v_shortage.requested_quantity-v_shortage.fulfilled_quantity) then
    raise exception 'الكمية تتجاوز المتبقي في نواقص العميل.';
  end if;
  return new;
end;
$$;
drop trigger if exists erp_validate_customer_shortage_sales_line_trigger on public.erp_sales_lines;
create trigger erp_validate_customer_shortage_sales_line_trigger
before insert or update of shortage_id on public.erp_sales_lines
for each row execute function public.erp_validate_customer_shortage_sales_line();

create or replace function public.erp_consume_campaign_quantities_on_post()
returns trigger
language plpgsql
security definer
set search_path = public
set row_security = off
as $$
declare
  v_line record;
  v_remaining numeric;
  v_shortage public.erp_customer_shortages%rowtype;
  v_new_fulfilled numeric;
begin
  if old.status is distinct from new.status and new.status='posted' then
    for v_line in
      select l.campaign_item_id, coalesce(l.base_quantity,l.quantity) as qty
      from public.erp_sales_lines l
      where l.document_id=new.id and l.campaign_item_id is not null
      order by l.campaign_item_id
    loop
      select remaining_quantity into v_remaining
      from public.erp_sales_campaign_items where id=v_line.campaign_item_id for update;
      if not found then raise exception 'بند العرض المرتبط بالفاتورة غير موجود.'; end if;
      if v_remaining is not null and v_remaining < v_line.qty then
        raise exception 'انتهت كمية العرض قبل ترحيل الفاتورة.';
      end if;
      update public.erp_sales_campaign_items
      set remaining_quantity=case when remaining_quantity is null then null else greatest(remaining_quantity-v_line.qty,0) end,
          is_active=case when remaining_quantity is null then is_active else (remaining_quantity-v_line.qty)>0 end
      where id=v_line.campaign_item_id;
    end loop;

    for v_line in
      select l.shortage_id, coalesce(l.base_quantity,l.quantity) as qty
      from public.erp_sales_lines l
      where l.document_id=new.id and l.shortage_id is not null
      order by l.shortage_id
    loop
      select * into v_shortage from public.erp_customer_shortages where id=v_line.shortage_id for update;
      if not found or v_shortage.status not in ('open','partial') then
        raise exception 'نقص العميل المرتبط بالفاتورة لم يعد مفتوحًا.';
      end if;
      v_new_fulfilled := v_shortage.fulfilled_quantity + v_line.qty;
      if v_new_fulfilled > v_shortage.requested_quantity then
        raise exception 'الكمية المرحّلة تتجاوز إجمالي نقص العميل.';
      end if;
      update public.erp_customer_shortages
      set fulfilled_quantity=v_new_fulfilled,
          status=case when v_new_fulfilled>=requested_quantity then 'closed' else 'partial' end,
          closed_at=case when v_new_fulfilled>=requested_quantity then now() else null end
      where id=v_line.shortage_id;
    end loop;
  end if;
  return new;
end;
$$;

create or replace function public.erp_add_operational_document_lines_v2(
  p_document_id uuid,
  p_kind text,
  p_lines jsonb
)
returns integer
language plpgsql
security definer
set search_path = public
set row_security = off
as $$
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
$$;
revoke all on function public.erp_add_operational_document_lines_v2(uuid,text,jsonb) from public, anon;
grant execute on function public.erp_add_operational_document_lines_v2(uuid,text,jsonb) to authenticated;
