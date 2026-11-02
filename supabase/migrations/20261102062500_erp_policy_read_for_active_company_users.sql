-- Allow an active ERP user to read their own ERP identity and company
-- policies even when their account is not represented in erp_company_members.
-- Policy writes remain restricted to company owners and administrators.

drop policy if exists erp_users_read_self on public.erp_users;
create policy erp_users_read_self
on public.erp_users
for select
to authenticated
using (
  auth_user_id = (select auth.uid())
  and is_active = true
);

create schema if not exists private;
revoke all on schema private from public;
grant usage on schema private to authenticated;

create or replace function private.can_read_erp_company_policies(p_company_id uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
set row_security = off
as $function$
  select p_company_id is not null
    and (select auth.uid()) is not null
    and (
      exists (
        select 1
        from public.erp_company_members m
        where m.company_id = p_company_id
          and m.user_id = (select auth.uid())
          and m.is_active = true
      )
      or exists (
        select 1
        from public.erp_users u
        where u.company_id = p_company_id
          and u.auth_user_id = (select auth.uid())
          and u.is_active = true
      )
    );
$function$;

revoke all on function private.can_read_erp_company_policies(uuid) from public;
grant execute on function private.can_read_erp_company_policies(uuid) to authenticated;

drop policy if exists erp_program_policies_company_user_read on public.erp_program_policies;
create policy erp_program_policies_company_user_read
on public.erp_program_policies
for select
to authenticated
using (private.can_read_erp_company_policies(company_id));
