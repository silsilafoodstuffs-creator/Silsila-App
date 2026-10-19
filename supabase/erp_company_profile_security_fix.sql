-- LEGACY / NARROW REPAIR ONLY.
-- For a new setup or missing company membership/RPC objects, prefer
-- supabase/erp_company_profile_membership_repair.sql followed by
-- supabase/erp_base_master_data_rls_fix.sql after the base ERP schema.
-- Never expose a service-role key in Flutter.

begin;

-- Keep the company table readable only to active company members.
alter table public.erp_companies enable row level security;

drop policy if exists erp_companies_select_member on public.erp_companies;
create policy erp_companies_select_member
on public.erp_companies
for select to authenticated
using (public.erp_user_can_access_company(id));

-- Direct updates are also restricted to active owners and admins.
drop policy if exists erp_companies_update_admin on public.erp_companies;
create policy erp_companies_update_admin
on public.erp_companies
for update to authenticated
using (public.erp_user_has_company_role(id, array['owner','admin']::text[]))
with check (public.erp_user_has_company_role(id, array['owner','admin']::text[]));

-- A narrowly scoped RPC makes the authorization check explicit and avoids
-- relying on the client to interpret a zero-row UPDATE as a successful save.
create or replace function public.erp_update_company_profile(
  p_company_id uuid,
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
  v_currency text := upper(trim(coalesce(p_base_currency, 'EGP')));
  v_updated_id uuid;
begin
  if v_user_id is null then
    raise exception 'يجب تسجيل الدخول قبل تعديل بيانات الشركة';
  end if;

  if p_company_id is null then
    raise exception 'معرّف الشركة مطلوب';
  end if;

  if not public.erp_user_has_company_role(
    p_company_id, array['owner','admin']::text[]
  ) then
    raise exception 'لا تملك صلاحية مالك أو مدير نشط لتعديل بيانات هذه الشركة';
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

  update public.erp_companies
  set legal_name = trim(p_legal_name),
      trade_name = nullif(trim(p_trade_name), ''),
      tax_number = nullif(trim(p_tax_number), ''),
      commercial_register = nullif(trim(p_commercial_register), ''),
      phone = nullif(trim(p_phone), ''),
      email = nullif(trim(p_email), ''),
      address = nullif(trim(p_address), ''),
      base_currency = v_currency,
      updated_at = now()
  where id = p_company_id
  returning id into v_updated_id;

  if v_updated_id is null then
    raise exception 'الشركة غير موجودة أو لا يمكن تعديل سجلها';
  end if;

  return v_updated_id;
end;
$$;

revoke all on function public.erp_update_company_profile(uuid,text,text,text,text,text,text,text,text) from public, anon;
grant execute on function public.erp_update_company_profile(uuid,text,text,text,text,text,text,text,text) to authenticated;
grant select, update on public.erp_companies to authenticated;

commit;

-- Diagnostic query (run separately after applying if a user still cannot save):
-- select c.id, c.legal_name, m.user_id, m.member_role, m.is_active
-- from public.erp_companies c
-- left join public.erp_company_members m on m.company_id = c.id
-- where c.id = '<COMPANY_UUID>'::uuid;
-- The currently signed-in user's auth.users.id must have an active owner/admin
-- membership row for this company. Do not grant ownership by blindly inserting
-- the current user; verify the company and account identity first.
