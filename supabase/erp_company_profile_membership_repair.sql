-- Silsila ERP company profile save repair.
-- Safe to apply to the current ERP core schema; creates only the missing
-- membership/security objects and the two company profile RPCs.
begin;

create table if not exists public.erp_company_members (
  id uuid primary key default gen_random_uuid(),
  company_id uuid not null references public.erp_companies(id) on delete cascade,
  user_id uuid not null references auth.users(id) on delete cascade,
  member_role text not null default 'viewer'
    check (member_role in ('owner','admin','accountant','manager','operator','viewer')),
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  unique (company_id, user_id)
);

create index if not exists erp_company_members_user_active_company_idx
  on public.erp_company_members(user_id, is_active, company_id);

alter table public.erp_company_members enable row level security;
alter table public.erp_companies enable row level security;

create or replace function public.erp_user_can_access_company(p_company_id uuid)
returns boolean
language sql
stable
security definer
set search_path = public
set row_security = off
as $$
  select p_company_id is not null and exists (
    select 1
    from public.erp_company_members m
    where m.company_id = p_company_id
      and m.user_id = (select auth.uid())
      and m.is_active = true
  );
$$;

create or replace function public.erp_user_has_company_role(
  p_company_id uuid,
  p_allowed_roles text[]
)
returns boolean
language sql
stable
security definer
set search_path = public
set row_security = off
as $$
  select p_company_id is not null and coalesce(array_length(p_allowed_roles, 1), 0) > 0 and exists (
    select 1
    from public.erp_company_members m
    where m.company_id = p_company_id
      and m.user_id = (select auth.uid())
      and m.is_active = true
      and m.member_role = any(p_allowed_roles)
  );
$$;

revoke all on function public.erp_user_can_access_company(uuid) from public, anon;
revoke all on function public.erp_user_has_company_role(uuid, text[]) from public, anon;
grant execute on function public.erp_user_can_access_company(uuid) to authenticated;
grant execute on function public.erp_user_has_company_role(uuid, text[]) to authenticated;

drop policy if exists erp_company_members_select_self_or_admin on public.erp_company_members;
create policy erp_company_members_select_self_or_admin
on public.erp_company_members
for select to authenticated
using (
  user_id = (select auth.uid())
  or public.erp_user_has_company_role(company_id, array['owner','admin']::text[])
);

drop policy if exists erp_company_members_insert_admin on public.erp_company_members;
create policy erp_company_members_insert_admin
on public.erp_company_members
for insert to authenticated
with check (
  public.erp_user_has_company_role(company_id, array['owner','admin']::text[])
  and member_role in ('admin','accountant','manager','operator','viewer')
);

drop policy if exists erp_company_members_update_admin on public.erp_company_members;
create policy erp_company_members_update_admin
on public.erp_company_members
for update to authenticated
using (
  public.erp_user_has_company_role(company_id, array['owner','admin']::text[])
  and member_role <> 'owner'
)
with check (
  public.erp_user_has_company_role(company_id, array['owner','admin']::text[])
  and member_role in ('admin','accountant','manager','operator','viewer')
);

drop policy if exists erp_company_members_delete_admin on public.erp_company_members;
create policy erp_company_members_delete_admin
on public.erp_company_members
for delete to authenticated
using (
  public.erp_user_has_company_role(company_id, array['owner','admin']::text[])
  and member_role <> 'owner'
);

drop policy if exists erp_companies_select_member on public.erp_companies;
create policy erp_companies_select_member
on public.erp_companies
for select to authenticated
using (public.erp_user_can_access_company(id));

drop policy if exists erp_companies_insert_rpc_only on public.erp_companies;
create policy erp_companies_insert_rpc_only
on public.erp_companies
for insert to authenticated
with check (false);

drop policy if exists erp_companies_update_admin on public.erp_companies;
create policy erp_companies_update_admin
on public.erp_companies
for update to authenticated
using (public.erp_user_has_company_role(id, array['owner','admin']::text[]))
with check (public.erp_user_has_company_role(id, array['owner','admin']::text[]));

drop policy if exists erp_companies_delete_rpc_only on public.erp_companies;
create policy erp_companies_delete_rpc_only
on public.erp_companies
for delete to authenticated
using (false);

revoke all on public.erp_companies from anon;
revoke all on public.erp_company_members from anon;
revoke all on public.erp_companies from authenticated;
revoke all on public.erp_company_members from authenticated;
grant select, update on public.erp_companies to authenticated;
grant select, insert, update, delete on public.erp_company_members to authenticated;

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
  v_user_id uuid := (select auth.uid());
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
  v_user_id uuid := (select auth.uid());
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

revoke all on function public.erp_create_company(text,text,text,text,text,text,text,text) from public, anon;
revoke all on function public.erp_update_company_profile(uuid,text,text,text,text,text,text,text,text) from public, anon;
grant execute on function public.erp_create_company(text,text,text,text,text,text,text,text) to authenticated;
grant execute on function public.erp_update_company_profile(uuid,text,text,text,text,text,text,text,text) to authenticated;

commit;
