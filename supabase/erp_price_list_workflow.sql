-- Transaction-safe price list creation, including replacement of the default list.
-- Apply after erp_master_data_schema.sql and erp_security_membership.sql.

create or replace function public.erp_create_price_list(
  p_company_id uuid,
  p_code text,
  p_name text,
  p_kind text,
  p_is_default boolean default false,
  p_currency_code text default 'EGP',
  p_notes text default null
)
returns uuid
language plpgsql
security definer
set search_path = public
set row_security = off
as $$
declare
  v_id uuid;
  v_currency text := upper(coalesce(nullif(trim(p_currency_code), ''), 'EGP'));
begin
  if not public.erp_user_has_company_role(p_company_id, array['owner','admin','manager','accountant']::text[]) then
    raise exception 'ليست لديك صلاحية إنشاء قوائم الأسعار';
  end if;
  if nullif(trim(p_code), '') is null or nullif(trim(p_name), '') is null then
    raise exception 'كود قائمة الأسعار واسمها مطلوبان';
  end if;
  if p_kind is null or p_kind not in ('sale','purchase') then
    raise exception 'نوع قائمة الأسعار غير صحيح';
  end if;
  if length(v_currency) <> 3 then raise exception 'رمز العملة يجب أن يتكون من ثلاثة أحرف'; end if;

  perform pg_advisory_xact_lock(hashtextextended(p_company_id::text || ':price-list:' || p_kind, 0));
  if coalesce(p_is_default, false) then
    update public.erp_price_lists
    set is_default = false, updated_at = now()
    where company_id = p_company_id and price_kind = p_kind and is_active and is_default;
  end if;

  insert into public.erp_price_lists(
    company_id, price_list_code, price_list_name, price_kind,
    currency_code, is_default, is_active, notes
  ) values (
    p_company_id, trim(p_code), trim(p_name), p_kind,
    v_currency::char(3), coalesce(p_is_default, false), true, nullif(trim(p_notes), '')
  ) returning id into v_id;
  return v_id;
end;
$$;

revoke all on function public.erp_create_price_list(uuid, text, text, text, boolean, text, text) from public, anon;
grant execute on function public.erp_create_price_list(uuid, text, text, text, boolean, text, text) to authenticated;

comment on function public.erp_create_price_list(uuid, text, text, text, boolean, text, text) is
  'Creates a price list atomically and maintains at most one active default list per company and price kind.';
