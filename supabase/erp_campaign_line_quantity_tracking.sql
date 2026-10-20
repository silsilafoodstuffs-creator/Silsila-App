-- Track campaign-origin invoice lines and consume limited offer quantity only on posting.
alter table public.erp_sales_lines
  add column if not exists campaign_item_id uuid references public.erp_sales_campaign_items(id) on delete set null;

create index if not exists erp_sales_lines_campaign_item_idx
  on public.erp_sales_lines(campaign_item_id) where campaign_item_id is not null;

create or replace function public.erp_validate_campaign_sales_line()
returns trigger
language plpgsql
security definer
set search_path = public
set row_security = off
as $$
declare
  v_campaign public.erp_sales_campaign_items%rowtype;
  v_company uuid;
  v_status text;
  v_item uuid;
  v_remaining numeric;
begin
  if new.campaign_item_id is null then return new; end if;
  select d.company_id,d.status into v_company,v_status
    from public.erp_sales_documents d where d.id=new.document_id;
  if v_company is null or v_status <> 'draft' then
    raise exception 'لا يمكن ربط عرض إلا ببند في مسودة مبيعات.';
  end if;
  select * into v_campaign from public.erp_sales_campaign_items
    where id=new.campaign_item_id for update;
  if not found or not v_campaign.is_active or v_campaign.company_id<>v_company or v_campaign.item_id<>new.item_id then
    raise exception 'بند العرض غير نشط أو لا يطابق الصنف والشركة.';
  end if;
  if v_campaign.remaining_quantity is not null then
    v_remaining := v_campaign.remaining_quantity;
    if coalesce(new.base_quantity,new.quantity)>v_remaining then
      raise exception 'الكمية المطلوبة تتجاوز المتبقي في العرض (%).',v_remaining;
    end if;
  end if;
  return new;
end;
$$;

drop trigger if exists erp_validate_campaign_sales_line_trigger on public.erp_sales_lines;
create trigger erp_validate_campaign_sales_line_trigger
before insert or update of campaign_item_id on public.erp_sales_lines
for each row execute function public.erp_validate_campaign_sales_line();

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
  end if;
  return new;
end;
$$;

drop trigger if exists erp_consume_campaign_quantities_on_post_trigger on public.erp_sales_documents;
create trigger erp_consume_campaign_quantities_on_post_trigger
after update of status on public.erp_sales_documents
for each row execute function public.erp_consume_campaign_quantities_on_post();

-- The picker treats max_quantity as the finite quantity limit for existing campaigns.
update public.erp_sales_campaign_items
set offer_quantity=coalesce(offer_quantity,max_quantity,100),
    remaining_quantity=coalesce(remaining_quantity,max_quantity,100),
    max_quantity=coalesce(max_quantity,offer_quantity,100)
where offer_quantity is null or remaining_quantity is null or max_quantity is null;
