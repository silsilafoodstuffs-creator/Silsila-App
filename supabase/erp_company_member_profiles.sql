-- Company-scoped directory details for ERP members; authentication credentials remain in Supabase Auth.
begin;

create table if not exists public.erp_company_member_profiles (
  id uuid primary key default gen_random_uuid(),
  company_id uuid not null references public.erp_companies(id) on delete cascade,
  user_id uuid not null references auth.users(id) on delete cascade,
  display_name text not null check (length(trim(display_name)) between 1 and 160),
  job_title text,
  branch_id uuid references public.erp_branches(id) on delete set null,
  updated_by uuid references auth.users(id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique(company_id, user_id)
);

create index if not exists erp_company_member_profiles_search_idx
  on public.erp_company_member_profiles(company_id, display_name, job_title, branch_id);

create or replace function public.erp_validate_company_member_profile()
returns trigger
language plpgsql
set search_path = public
as $$
begin
  if new.branch_id is not null and not exists (
    select 1 from public.erp_branches b
    where b.id = new.branch_id and b.company_id = new.company_id
  ) then
    raise exception 'الفرع المحدد لا يتبع الشركة نفسها.';
  end if;
  if new.updated_by is not null and new.updated_by <> auth.uid() then
    raise exception 'قيمة updated_by غير صالحة.';
  end if;
  return new;
end;
$$;

drop trigger if exists erp_validate_company_member_profile_trigger on public.erp_company_member_profiles;
create trigger erp_validate_company_member_profile_trigger
before insert or update on public.erp_company_member_profiles
for each row execute function public.erp_validate_company_member_profile();

drop trigger if exists erp_company_member_profiles_updated_at on public.erp_company_member_profiles;
create trigger erp_company_member_profiles_updated_at
before update on public.erp_company_member_profiles
for each row execute function public.erp_set_updated_at();

alter table public.erp_company_member_profiles enable row level security;

drop policy if exists erp_company_member_profiles_select_admin on public.erp_company_member_profiles;
create policy erp_company_member_profiles_select_admin
on public.erp_company_member_profiles for select to authenticated
using (public.erp_user_has_company_role(company_id, array['owner','admin']::text[]));

drop policy if exists erp_company_member_profiles_insert_admin on public.erp_company_member_profiles;
create policy erp_company_member_profiles_insert_admin
on public.erp_company_member_profiles for insert to authenticated
with check (
  (updated_by is null or updated_by = auth.uid())
  and public.erp_user_has_company_role(company_id, array['owner','admin']::text[])
  and exists (
    select 1 from public.erp_company_members m
    where m.company_id = erp_company_member_profiles.company_id
      and m.user_id = erp_company_member_profiles.user_id
  )
);

drop policy if exists erp_company_member_profiles_update_admin on public.erp_company_member_profiles;
create policy erp_company_member_profiles_update_admin
on public.erp_company_member_profiles for update to authenticated
using (public.erp_user_has_company_role(company_id, array['owner','admin']::text[]))
with check (
  (updated_by is null or updated_by = auth.uid())
  and public.erp_user_has_company_role(company_id, array['owner','admin']::text[])
);

drop policy if exists erp_company_member_profiles_delete_admin on public.erp_company_member_profiles;
create policy erp_company_member_profiles_delete_admin
on public.erp_company_member_profiles for delete to authenticated
using (public.erp_user_has_company_role(company_id, array['owner','admin']::text[]));

grant select, insert, update, delete on public.erp_company_member_profiles to authenticated;
commit;
