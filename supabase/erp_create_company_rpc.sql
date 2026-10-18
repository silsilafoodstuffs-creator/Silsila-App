-- Secure company creation for authenticated ERP users.
-- Apply in Supabase SQL Editor after erp_schema.sql and erp_security_membership.sql.

create or replace function public.erp_create_company(
  p_legal_name text,
  p_trade_name text default null,
  p_tax_number text default null,
  p_commercial_register text default null,
  p_phone text default null,
  p_email text default null,
  p_address text default null,
  p_base_currency text default 'EGP'
)
returns uuid
language plpgsql
security definer
set search_path = public
set row_security = off
as $$
declare
  v_user_id uuid := auth.uid();
  v_company_id uuid;
  v_currency text := upper(trim(coalesce(p_base_currency, 'EGP')));
begin
  if v_user_id is null then
    raise exception 'يجب تسجيل الدخول قبل تسجيل الشركة';
  end if;
  if nullif(trim(p_legal_name), '') is null then
    raise exception 'الاسم القانوني للشركة مطلوب';
  end if;
  if length(trim(p_legal_name)) > 250 then
    raise exception 'اسم الشركة أطول من المسموح';
  end if;
  if v_currency !~ '^[A-Z]{3}$' then
    raise exception 'رمز العملة يجب أن يتكون من 3 أحرف مثل EGP';
  end if;

  insert into public.erp_companies (
    legal_name, trade_name, tax_number, commercial_register,
    phone, email, address, base_currency
  ) values (
    trim(p_legal_name), nullif(trim(p_trade_name), ''),
    nullif(trim(p_tax_number), ''), nullif(trim(p_commercial_register), ''),
    nullif(trim(p_phone), ''), nullif(trim(p_email), ''),
    nullif(trim(p_address), ''), v_currency
  )
  returning id into v_company_id;

  insert into public.erp_company_members (company_id, user_id, member_role, is_active)
  values (v_company_id, v_user_id, 'owner', true);

  return v_company_id;
end;
$$;

revoke all on function public.erp_create_company(text,text,text,text,text,text,text,text) from public, anon;
grant execute on function public.erp_create_company(text,text,text,text,text,text,text,text) to authenticated;
