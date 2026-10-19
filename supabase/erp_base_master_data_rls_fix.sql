-- Company-scoped RLS policies for the ERP tables created by erp_core_schema_20261019.
-- This file intentionally targets only base tables confirmed present in the live database.
begin;

-- Remove broad public-client grants from ERP financial/master-data tables.
revoke all on public.erp_branches, public.erp_fiscal_periods, public.erp_accounts,
  public.erp_cashboxes, public.erp_warehouses, public.erp_item_groups,
  public.erp_items, public.erp_parties, public.erp_journal_entries,
  public.erp_journal_lines from anon, authenticated;

grant select, insert, update, delete on public.erp_branches,
  public.erp_fiscal_periods, public.erp_accounts, public.erp_cashboxes,
  public.erp_warehouses, public.erp_item_groups, public.erp_items,
  public.erp_parties, public.erp_journal_entries, public.erp_journal_lines
to authenticated;

-- Direct company tables: membership for reads, role checks for writes.
do $$
declare
  t text;
begin
  foreach t in array array[
    'erp_branches','erp_accounts','erp_cashboxes',
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

-- Fiscal periods: only owner/admin/accountant may change them.
drop policy if exists erp_fiscal_periods_select_member on public.erp_fiscal_periods;
create policy erp_fiscal_periods_select_member on public.erp_fiscal_periods
for select to authenticated using (public.erp_user_can_access_company(company_id));

drop policy if exists erp_fiscal_periods_insert_operator on public.erp_fiscal_periods;
create policy erp_fiscal_periods_insert_operator on public.erp_fiscal_periods
for insert to authenticated with check (
  status = 'open' and public.erp_user_has_company_role(company_id, array['owner','admin','accountant']::text[])
);

drop policy if exists erp_fiscal_periods_update_operator on public.erp_fiscal_periods;
create policy erp_fiscal_periods_update_operator on public.erp_fiscal_periods
for update to authenticated
using (public.erp_user_has_company_role(company_id, array['owner','admin','accountant']::text[]))
with check (public.erp_user_has_company_role(company_id, array['owner','admin','accountant']::text[]));

drop policy if exists erp_fiscal_periods_delete_admin on public.erp_fiscal_periods;
create policy erp_fiscal_periods_delete_admin on public.erp_fiscal_periods
for delete to authenticated using (
  status = 'open'
  and public.erp_user_has_company_role(company_id, array['owner','admin']::text[])
  and not exists (
    select 1 from public.erp_journal_entries e
    where e.company_id = erp_fiscal_periods.company_id
      and e.entry_date between erp_fiscal_periods.starts_on and erp_fiscal_periods.ends_on
  )
);

-- Journal headers are company-readable and editable only in draft/accounting roles.
drop policy if exists erp_journal_entries_select_member on public.erp_journal_entries;
create policy erp_journal_entries_select_member on public.erp_journal_entries
for select to authenticated using (public.erp_user_can_access_company(company_id));

drop policy if exists erp_journal_entries_insert_accounting on public.erp_journal_entries;
create policy erp_journal_entries_insert_accounting on public.erp_journal_entries
for insert to authenticated with check (
  status = 'draft' and posted_at is null and posted_by is null
  and public.erp_user_has_company_role(company_id, array['owner','admin','accountant']::text[])
);

drop policy if exists erp_journal_entries_update_accounting on public.erp_journal_entries;
create policy erp_journal_entries_update_accounting on public.erp_journal_entries
for update to authenticated
using (public.erp_user_has_company_role(company_id, array['owner','admin','accountant']::text[]))
with check (public.erp_user_has_company_role(company_id, array['owner','admin','accountant']::text[]));

drop policy if exists erp_journal_entries_delete_admin on public.erp_journal_entries;
create policy erp_journal_entries_delete_admin on public.erp_journal_entries
for delete to authenticated using (
  status = 'draft' and public.erp_user_has_company_role(company_id, array['owner','admin']::text[])
);

-- Journal lines inherit tenant scope from their parent entry and must reference same-company records.
drop policy if exists erp_journal_lines_select_member on public.erp_journal_lines;
create policy erp_journal_lines_select_member on public.erp_journal_lines
for select to authenticated using (exists (
  select 1 from public.erp_journal_entries e
  where e.id = entry_id and public.erp_user_can_access_company(e.company_id)
));

drop policy if exists erp_journal_lines_insert_accounting on public.erp_journal_lines;
create policy erp_journal_lines_insert_accounting on public.erp_journal_lines
for insert to authenticated with check (exists (
  select 1
  from public.erp_journal_entries e
  join public.erp_accounts a on a.id = erp_journal_lines.account_id and a.company_id = e.company_id
  where e.id = erp_journal_lines.entry_id
    and e.status = 'draft'
    and (erp_journal_lines.party_id is null or exists (
      select 1 from public.erp_parties p
      where p.id = erp_journal_lines.party_id and p.company_id = e.company_id
    ))
    and (erp_journal_lines.branch_id is null or exists (
      select 1 from public.erp_branches b
      where b.id = erp_journal_lines.branch_id and b.company_id = e.company_id
    ))
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
  select 1
  from public.erp_journal_entries e
  join public.erp_accounts a on a.id = erp_journal_lines.account_id and a.company_id = e.company_id
  where e.id = erp_journal_lines.entry_id and e.status = 'draft'
    and (erp_journal_lines.party_id is null or exists (
      select 1 from public.erp_parties p
      where p.id = erp_journal_lines.party_id and p.company_id = e.company_id
    ))
    and (erp_journal_lines.branch_id is null or exists (
      select 1 from public.erp_branches b
      where b.id = erp_journal_lines.branch_id and b.company_id = e.company_id
    ))
    and public.erp_user_has_company_role(e.company_id, array['owner','admin','accountant']::text[])
));

drop policy if exists erp_journal_lines_delete_accounting on public.erp_journal_lines;
create policy erp_journal_lines_delete_accounting on public.erp_journal_lines
for delete to authenticated using (exists (
  select 1 from public.erp_journal_entries e
  where e.id = entry_id and e.status = 'draft'
    and public.erp_user_has_company_role(e.company_id, array['owner','admin','accountant']::text[])
));

commit;
