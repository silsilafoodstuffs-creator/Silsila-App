begin;

create table if not exists public.erp_studio_layout_profiles (
  id uuid primary key default gen_random_uuid(),
  company_id uuid not null references public.erp_companies(id) on delete cascade,
  profile_key text not null check (length(trim(profile_key)) between 1 and 120),
  profile_json jsonb not null default '{}'::jsonb check (jsonb_typeof(profile_json) = 'object'),
  updated_by uuid not null default auth.uid() references auth.users(id),
  updated_at timestamptz not null default now(),
  unique (company_id, profile_key)
);

create index if not exists erp_studio_layout_profiles_company_updated_idx
  on public.erp_studio_layout_profiles(company_id, updated_at desc);

alter table public.erp_studio_layout_profiles enable row level security;

drop policy if exists erp_studio_layout_profiles_read_member
  on public.erp_studio_layout_profiles;
create policy erp_studio_layout_profiles_read_member
on public.erp_studio_layout_profiles
for select to authenticated
using (public.erp_user_can_access_company(company_id));

drop policy if exists erp_studio_layout_profiles_insert_admin
  on public.erp_studio_layout_profiles;
create policy erp_studio_layout_profiles_insert_admin
on public.erp_studio_layout_profiles
for insert to authenticated
with check (
  public.erp_user_has_company_role(company_id, array['owner','admin']::text[])
  and updated_by = auth.uid()
);

drop policy if exists erp_studio_layout_profiles_update_admin
  on public.erp_studio_layout_profiles;
create policy erp_studio_layout_profiles_update_admin
on public.erp_studio_layout_profiles
for update to authenticated
using (public.erp_user_has_company_role(company_id, array['owner','admin']::text[]))
with check (
  public.erp_user_has_company_role(company_id, array['owner','admin']::text[])
  and updated_by = auth.uid()
);

drop policy if exists erp_studio_layout_profiles_delete_admin
  on public.erp_studio_layout_profiles;
create policy erp_studio_layout_profiles_delete_admin
on public.erp_studio_layout_profiles
for delete to authenticated
using (public.erp_user_has_company_role(company_id, array['owner','admin']::text[]));

revoke all on public.erp_studio_layout_profiles from anon, authenticated;
grant select, insert, update, delete on public.erp_studio_layout_profiles to authenticated;

commit;
