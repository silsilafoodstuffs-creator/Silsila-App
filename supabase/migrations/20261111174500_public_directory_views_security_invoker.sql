-- Make public directory views obey caller privileges and profiles RLS.
-- The policy exposes only the same approved, non-management directory rows
-- already selected by the public directory views.
grant select (id, full_name, activity_type, customer_type, governorate, district,
              account_status, role, supplier_type, avatar_url, account_type)
on table public.profiles to anon, authenticated;

drop policy if exists profiles_public_approved_directory_select on public.profiles;
create policy profiles_public_approved_directory_select
on public.profiles
for select
to anon, authenticated
using (
  account_status = any (array['approved','active','مفعل','معتمد']::text[])
  and role <> all (array['management','admin','platform_admin','super_admin']::text[])
);

create or replace view public.supplier_directory
with (security_invoker = true)
as
select id, full_name, activity_type, supplier_type, governorate, district, account_status
from public.profiles
where role = 'supplier'
  and account_status = any (array['approved','active','مفعل','معتمد']::text[]);

create or replace view public.customer_directory
with (security_invoker = true)
as
select id, full_name, activity_type, customer_type, governorate, district, account_status
from public.profiles
where role = 'customer'
  and account_status = any (array['approved','active','مفعل','معتمد']::text[]);

create or replace view public.profile_public_directory
with (security_invoker = true)
as
select id, full_name, avatar_url, role, account_type
from public.profiles
where account_status = any (array['approved','active','مفعل','معتمد']::text[])
  and role <> all (array['management','admin','platform_admin','super_admin']::text[]);

create or replace view public.supplier_public_details
with (security_invoker = true)
as
select sd.supplier_id, sd.business_name, sd.description, sd.logo_url, sd.cover_url,
       sd.supplier_type, sd.activity_type, sd.pricing_policy, sd.minimum_invoice,
       sd.minimum_items, sd.accepts_negotiation, sd.is_verified, sd.rating, sd.created_at
from public.supplier_details sd
join public.profiles p on p.id = sd.supplier_id
where sd.is_active = true
  and p.role = 'supplier'
  and p.account_status = any (array['approved','active','مفعل','معتمد']::text[]);

comment on policy profiles_public_approved_directory_select on public.profiles is
'Allows only approved non-management profile rows needed by public directory views; sensitive profile columns remain ungranted to anon.';
