-- Resolve the effective unit price for a customer/supplier and item.
-- Apply after erp_master_data_schema.sql and erp_security_membership.sql.
-- This function only resolves a price; it does not create or modify documents.

create or replace function public.erp_resolve_item_price(
  p_company_id uuid,
  p_item_id uuid,
  p_price_kind text,
  p_quantity numeric default 1,
  p_party_id uuid default null,
  p_price_date date default current_date
)
returns table (
  item_id uuid,
  price_kind text,
  requested_quantity numeric,
  base_unit_price numeric,
  discount_percent numeric,
  net_unit_price numeric,
  currency_code char(3),
  price_list_id uuid,
  price_list_name text,
  price_source text
)
language plpgsql
security invoker
set search_path = public
as $$
declare
  v_item public.erp_items%rowtype;
  v_party_kind text;
  v_line record;
  v_base numeric(14,4);
  v_discount numeric(7,4) := 0;
  v_list_id uuid;
  v_list_name text;
  v_currency char(3) := 'EGP';
  v_source text := 'item_master';
begin
  if p_price_kind is null or p_price_kind not in ('sale','purchase') then
    raise exception 'نوع التسعير يجب أن يكون sale أو purchase';
  end if;
  if p_quantity is null or p_quantity <= 0 then
    raise exception 'الكمية المطلوبة يجب أن تكون أكبر من صفر';
  end if;
  if not public.erp_user_can_access_company(p_company_id) then
    raise exception 'ليست لديك صلاحية الوصول إلى الشركة';
  end if;

  select * into v_item from public.erp_items i
  where i.id = p_item_id and i.company_id = p_company_id and i.is_active;
  if not found then raise exception 'الصنف غير موجود أو غير نشط داخل الشركة'; end if;

  if p_party_id is not null then
    select p.party_kind into v_party_kind from public.erp_parties p
    where p.id = p_party_id and p.company_id = p_company_id and p.is_active;
    if not found then raise exception 'العميل أو المورد غير موجود أو غير نشط داخل الشركة'; end if;
    if p_price_kind = 'sale' and v_party_kind not in ('customer','both') then
      raise exception 'الطرف المحدد ليس عميلًا';
    elsif p_price_kind = 'purchase' and v_party_kind not in ('supplier','both') then
      raise exception 'الطرف المحدد ليس موردًا';
    end if;
  end if;

  v_base := case when p_price_kind = 'sale' then v_item.sale_price else v_item.purchase_price end;

  select l.id as price_list_id, l.price_list_name, l.currency_code, ln.unit_price, ln.discount_percent,
         case when pp.party_id is not null then 'party_price_list' else 'default_price_list' end as resolved_source
    into v_line
  from public.erp_price_lists l
  join public.erp_price_list_lines ln on ln.price_list_id = l.id
    and ln.company_id = p_company_id and ln.item_id = p_item_id
    and ln.min_quantity <= p_quantity
    and (ln.starts_on is null or ln.starts_on <= p_price_date)
    and (ln.ends_on is null or ln.ends_on >= p_price_date)
  left join public.erp_party_price_lists pp on pp.price_list_id = l.id
    and pp.company_id = p_company_id and pp.party_id = p_party_id
    and (pp.starts_on is null or pp.starts_on <= p_price_date)
    and (pp.ends_on is null or pp.ends_on >= p_price_date)
  where l.company_id = p_company_id and l.price_kind = p_price_kind and l.is_active
    and (l.starts_on is null or l.starts_on <= p_price_date)
    and (l.ends_on is null or l.ends_on >= p_price_date)
    and ((p_party_id is not null and pp.party_id is not null) or l.is_default)
  order by case when pp.party_id is not null then 0 else 1 end,
    ln.min_quantity desc,
    coalesce(ln.starts_on, l.starts_on, date '1900-01-01') desc,
    l.created_at desc
  limit 1;

  if found then
    v_base := v_line.unit_price;
    v_discount := coalesce(v_line.discount_percent, 0);
    v_list_id := v_line.price_list_id;
    v_list_name := v_line.price_list_name;
    v_currency := v_line.currency_code;
    v_source := v_line.resolved_source;
  end if;

  return query select p_item_id, p_price_kind, p_quantity, v_base, v_discount,
    round(v_base * (1 - v_discount / 100), 4), v_currency, v_list_id, v_list_name, v_source;
end;
$$;

revoke all on function public.erp_resolve_item_price(uuid, uuid, text, numeric, uuid, date) from public, anon;
grant execute on function public.erp_resolve_item_price(uuid, uuid, text, numeric, uuid, date) to authenticated;

comment on function public.erp_resolve_item_price(uuid, uuid, text, numeric, uuid, date) is
  'Resolves a party-specific or default price list line with quantity tiers and effective dates, falling back to the item master price.';
