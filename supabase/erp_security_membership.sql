-- Silsila ERP company membership and RLS policies.
-- Apply manually in Supabase SQL Editor after reviewing the project.
-- IMPORTANT: after applying, bootstrap the first owner by inserting their auth.users UUID
-- into public.erp_company_members for the chosen company. See docs/ERP_API_INTEGRATION.md.
-- Do not expose service-role keys in the Flutter app.

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

create index if not exists erp_company_members_user_idx
  on public.erp_company_members(user_id, is_active, company_id);

alter table public.erp_company_members enable row level security;

create or replace function public.erp_user_can_access_company(p_company_id uuid)
returns boolean
language sql
stable
security definer
set search_path = public
set row_security = off
as $$
  select exists (
    select 1
    from public.erp_company_members m
    where m.company_id = p_company_id
      and m.user_id = auth.uid()
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
  select exists (
    select 1
    from public.erp_company_members m
    where m.company_id = p_company_id
      and m.user_id = auth.uid()
      and m.is_active = true
      and m.member_role = any(p_allowed_roles)
  );
$$;

revoke all on function public.erp_user_can_access_company(uuid) from public, anon;
revoke all on function public.erp_user_has_company_role(uuid,text[]) from public, anon;
grant execute on function public.erp_user_can_access_company(uuid) to authenticated;
grant execute on function public.erp_user_has_company_role(uuid,text[]) to authenticated;

drop policy if exists erp_members_select_self_or_admin on public.erp_company_members;
create policy erp_members_select_self_or_admin
on public.erp_company_members for select to authenticated
using (
  user_id = auth.uid()
  or public.erp_user_has_company_role(company_id, array['owner','admin']::text[])
);

drop policy if exists erp_members_insert_admin on public.erp_company_members;
create policy erp_members_insert_admin
on public.erp_company_members for insert to authenticated
with check (public.erp_user_has_company_role(company_id, array['owner','admin']::text[]));

drop policy if exists erp_members_update_admin on public.erp_company_members;
create policy erp_members_update_admin
on public.erp_company_members for update to authenticated
using (public.erp_user_has_company_role(company_id, array['owner','admin']::text[]))
with check (public.erp_user_has_company_role(company_id, array['owner','admin']::text[]));

drop policy if exists erp_members_delete_admin on public.erp_company_members;
create policy erp_members_delete_admin
on public.erp_company_members for delete to authenticated
using (public.erp_user_has_company_role(company_id, array['owner','admin']::text[]));

-- Company master record: members may read; owner/admin manage.
drop policy if exists erp_companies_select_member on public.erp_companies;
create policy erp_companies_select_member on public.erp_companies
for select to authenticated using (public.erp_user_can_access_company(id));
drop policy if exists erp_companies_insert_admin on public.erp_companies;
create policy erp_companies_insert_admin on public.erp_companies
for insert to authenticated with check (false);
drop policy if exists erp_companies_update_admin on public.erp_companies;
create policy erp_companies_update_admin on public.erp_companies
for update to authenticated
using (public.erp_user_has_company_role(id, array['owner','admin']::text[]))
with check (public.erp_user_has_company_role(id, array['owner','admin']::text[]));
drop policy if exists erp_companies_delete_admin on public.erp_companies;
create policy erp_companies_delete_admin on public.erp_companies
for delete to authenticated using (false);

-- Shared predicate policies for tables carrying company_id.
do $$
declare
  t text;
begin
  foreach t in array array[
    'erp_branches','erp_fiscal_periods','erp_accounts','erp_cashboxes',
    'erp_warehouses','erp_item_groups','erp_items','erp_parties'
  ]
  loop
    execute format('drop policy if exists %I on public.%I', t || '_select_member', t);
    execute format(
      'create policy %I on public.%I for select to authenticated using (public.erp_user_can_access_company(company_id))',
      t || '_select_member', t
    );
    execute format('drop policy if exists %I on public.%I', t || '_insert_operator', t);
    execute format(
      'create policy %I on public.%I for insert to authenticated with check (public.erp_user_has_company_role(company_id, array[''owner'',''admin'',''manager'',''operator'',''accountant'']::text[]))',
      t || '_insert_operator', t
    );
    execute format('drop policy if exists %I on public.%I', t || '_update_operator', t);
    execute format(
      'create policy %I on public.%I for update to authenticated using (public.erp_user_has_company_role(company_id, array[''owner'',''admin'',''manager'',''operator'',''accountant'']::text[])) with check (public.erp_user_has_company_role(company_id, array[''owner'',''admin'',''manager'',''operator'',''accountant'']::text[]))',
      t || '_update_operator', t
    );
    execute format('drop policy if exists %I on public.%I', t || '_delete_admin', t);
    execute format(
      'create policy %I on public.%I for delete to authenticated using (public.erp_user_has_company_role(company_id, array[''owner'',''admin'']::text[]))',
      t || '_delete_admin', t
    );
  end loop;
end;
$$;

-- Journal headers are visible to company members. Only accounting/admin roles may
-- create or edit drafts; posting/reversal RPCs still perform their own validations.
drop policy if exists erp_journal_entries_select_member on public.erp_journal_entries;
create policy erp_journal_entries_select_member on public.erp_journal_entries
for select to authenticated using (public.erp_user_can_access_company(company_id));

drop policy if exists erp_journal_entries_insert_accounting on public.erp_journal_entries;
create policy erp_journal_entries_insert_accounting on public.erp_journal_entries
for insert to authenticated
with check (public.erp_user_has_company_role(company_id, array['owner','admin','accountant']::text[]));

drop policy if exists erp_journal_entries_update_accounting on public.erp_journal_entries;
create policy erp_journal_entries_update_accounting on public.erp_journal_entries
for update to authenticated
using (public.erp_user_has_company_role(company_id, array['owner','admin','accountant']::text[]))
with check (public.erp_user_has_company_role(company_id, array['owner','admin','accountant']::text[]));

drop policy if exists erp_journal_entries_delete_admin on public.erp_journal_entries;
create policy erp_journal_entries_delete_admin on public.erp_journal_entries
for delete to authenticated
using (status = 'draft' and public.erp_user_has_company_role(company_id, array['owner','admin']::text[]));

-- Journal lines inherit company access from their header. The account must belong
-- to that same company. A line cannot be attached to another company's entry/account.
drop policy if exists erp_journal_lines_select_member on public.erp_journal_lines;
create policy erp_journal_lines_select_member on public.erp_journal_lines
for select to authenticated
using (exists (
  select 1 from public.erp_journal_entries e
  where e.id = entry_id and public.erp_user_can_access_company(e.company_id)
));

drop policy if exists erp_journal_lines_insert_accounting on public.erp_journal_lines;
create policy erp_journal_lines_insert_accounting on public.erp_journal_lines
for insert to authenticated
with check (exists (
  select 1 from public.erp_journal_entries e
  join public.erp_accounts a on a.id = account_id and a.company_id = e.company_id
  where e.id = entry_id
    and e.status = 'draft'
    and public.erp_user_has_company_role(e.company_id, array['owner','admin','accountant']::text[])
));

drop policy if exists erp_journal_lines_update_accounting on public.erp_journal_lines;
create policy erp_journal_lines_update_accounting on public.erp_journal_lines
for update to authenticated
using (exists (
  select 1 from public.erp_journal_entries e
  where e.id = entry_id and e.status = 'draft'
    and public.erp_user_has_company_role(e.company_id, array['owner','admin','accountant']::text[])
))
with check (exists (
  select 1 from public.erp_journal_entries e
  join public.erp_accounts a on a.id = account_id and a.company_id = e.company_id
  where e.id = entry_id and e.status = 'draft'
    and public.erp_user_has_company_role(e.company_id, array['owner','admin','accountant']::text[])
));

drop policy if exists erp_journal_lines_delete_accounting on public.erp_journal_lines;
create policy erp_journal_lines_delete_accounting on public.erp_journal_lines
for delete to authenticated
using (exists (
  select 1 from public.erp_journal_entries e
  where e.id = entry_id and e.status = 'draft'
    and public.erp_user_has_company_role(e.company_id, array['owner','admin','accountant']::text[])
));

grant select, insert, update, delete on public.erp_company_members to authenticated;
grant select, insert, update, delete on public.erp_companies, public.erp_branches,
  public.erp_fiscal_periods, public.erp_accounts, public.erp_cashboxes,
  public.erp_warehouses, public.erp_item_groups, public.erp_items, public.erp_parties,
  public.erp_journal_entries, public.erp_journal_lines to authenticated;
