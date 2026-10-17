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

-- Prevent changes to posted journal headers and keep immutable identifiers stable.
create or replace function public.erp_guard_journal_entry_update()
returns trigger
language plpgsql
set search_path = public
as $$
declare
  v_count integer;
  v_debit numeric(18,2);
  v_credit numeric(18,2);
begin
  if old.company_id is distinct from new.company_id
     or old.entry_number is distinct from new.entry_number
     or old.source_type is distinct from new.source_type
     or old.source_id is distinct from new.source_id
     or old.created_by is distinct from new.created_by then
    raise exception 'لا يمكن تغيير الشركة أو رقم القيد أو مصدره أو منشئه';
  end if;
  if old.status <> 'draft' then
    raise exception 'القيد المرحّل غير قابل للتعديل؛ استخدم إجراء العكس المحاسبي';
  end if;
  if new.status not in ('draft','posted') then
    raise exception 'حالة القيد غير مسموح بها';
  end if;
  if new.status = 'posted' then
    select count(*), coalesce(sum(l.debit),0), coalesce(sum(l.credit),0)
      into v_count, v_debit, v_credit
    from public.erp_journal_lines l where l.entry_id = old.id;
    if v_count < 2 or v_debit <= 0 or v_debit <> v_credit then
      raise exception 'لا يمكن ترحيل القيد دون سطور متوازنة';
    end if;
    if exists (
      select 1 from public.erp_journal_lines l
      join public.erp_accounts a on a.id = l.account_id
      where l.entry_id = old.id
        and (a.company_id <> old.company_id or not a.is_active or not a.is_postable)
    ) then raise exception 'القيد يحتوي على حساب غير صالح'; end if;
    if exists (
      select 1 from public.erp_fiscal_periods fp
      where fp.company_id = old.company_id
        and new.entry_date between fp.starts_on and fp.ends_on
        and fp.status = 'closed'
    ) then raise exception 'لا يمكن ترحيل القيد داخل فترة مالية مغلقة'; end if;
  end if;
  return new;
end;
$$;

drop trigger if exists erp_journal_entry_immutable_guard on public.erp_journal_entries;
create trigger erp_journal_entry_immutable_guard
before update on public.erp_journal_entries
for each row execute function public.erp_guard_journal_entry_update();

-- Safe employee directory for attendance operators: intentionally excludes salary,
-- national identifiers, personal notes, and other sensitive fields.
create or replace view public.erp_employee_directory
as
select
  e.id, e.company_id, e.branch_id, e.employee_code, e.full_name,
  e.phone, e.job_title, e.department_name, e.hire_date,
  e.employment_status, e.is_active
from public.erp_employees e
where public.erp_user_can_access_company(e.company_id);

grant select on public.erp_employee_directory to authenticated;

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
    'erp_branches','erp_fiscal_periods','erp_accounts','erp_cashboxes','erp_cash_vouchers',
    'erp_warehouses','erp_item_groups','erp_items','erp_parties',
    'erp_attendance_records','erp_leave_requests'
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


-- Operational document headers use membership-scoped reads and role-limited writes.
do $$
declare
  t text;
begin
  foreach t in array array['erp_purchase_documents','erp_sales_documents']
  loop
    execute format('drop policy if exists %I on public.%I', t || '_select_member', t);
    execute format('create policy %I on public.%I for select to authenticated using (public.erp_user_can_access_company(company_id))', t || '_select_member', t);
    execute format('drop policy if exists %I on public.%I', t || '_insert_operator', t);
    execute format('create policy %I on public.%I for insert to authenticated with check (public.erp_user_has_company_role(company_id, array[''owner'',''admin'',''manager'',''operator'',''accountant'']::text[]))', t || '_insert_operator', t);
    execute format('drop policy if exists %I on public.%I', t || '_update_operator', t);
    execute format('create policy %I on public.%I for update to authenticated using (public.erp_user_has_company_role(company_id, array[''owner'',''admin'',''manager'',''operator'',''accountant'']::text[])) with check (public.erp_user_has_company_role(company_id, array[''owner'',''admin'',''manager'',''operator'',''accountant'']::text[]))', t || '_update_operator', t);
    execute format('drop policy if exists %I on public.%I', t || '_delete_admin', t);
    execute format('create policy %I on public.%I for delete to authenticated using (status = ''draft'' and public.erp_user_has_company_role(company_id, array[''owner'',''admin'']::text[]))', t || '_delete_admin', t);
  end loop;
end;
$$;


-- Operational documents must enter through a draft; posting is a guarded transition.
drop policy if exists erp_purchase_documents_insert_operator on public.erp_purchase_documents;
create policy erp_purchase_documents_insert_operator on public.erp_purchase_documents
for insert to authenticated with check (
  status = 'draft' and public.erp_user_has_company_role(company_id, array['owner','admin','manager','operator','accountant']::text[])
);
drop policy if exists erp_sales_documents_insert_operator on public.erp_sales_documents;
create policy erp_sales_documents_insert_operator on public.erp_sales_documents
for insert to authenticated with check (
  status = 'draft' and public.erp_user_has_company_role(company_id, array['owner','admin','manager','operator','accountant']::text[])
);
drop policy if exists erp_cash_vouchers_insert_operator on public.erp_cash_vouchers;
create policy erp_cash_vouchers_insert_operator on public.erp_cash_vouchers
for insert to authenticated with check (
  status = 'draft' and public.erp_user_has_company_role(company_id, array['owner','admin','manager','operator','accountant']::text[])
);

-- Document lines inherit company access through their header and must reference
-- items belonging to that same company.
drop policy if exists erp_purchase_lines_select_member on public.erp_purchase_lines;
create policy erp_purchase_lines_select_member on public.erp_purchase_lines
for select to authenticated using (exists (
  select 1 from public.erp_purchase_documents d
  where d.id = document_id and public.erp_user_can_access_company(d.company_id)
));
drop policy if exists erp_purchase_lines_insert_operator on public.erp_purchase_lines;
create policy erp_purchase_lines_insert_operator on public.erp_purchase_lines
for insert to authenticated with check (exists (
  select 1 from public.erp_purchase_documents d
  join public.erp_items i on i.id = item_id and i.company_id = d.company_id
  where d.id = document_id and d.status = 'draft'
    and public.erp_user_has_company_role(d.company_id, array['owner','admin','manager','operator','accountant']::text[])
));
drop policy if exists erp_purchase_lines_update_operator on public.erp_purchase_lines;
create policy erp_purchase_lines_update_operator on public.erp_purchase_lines
for update to authenticated using (exists (
  select 1 from public.erp_purchase_documents d where d.id = document_id and d.status = 'draft'
    and public.erp_user_has_company_role(d.company_id, array['owner','admin','manager','operator','accountant']::text[])
)) with check (exists (
  select 1 from public.erp_purchase_documents d
  join public.erp_items i on i.id = item_id and i.company_id = d.company_id
  where d.id = document_id and d.status = 'draft'
    and public.erp_user_has_company_role(d.company_id, array['owner','admin','manager','operator','accountant']::text[])
));
drop policy if exists erp_purchase_lines_delete_operator on public.erp_purchase_lines;
create policy erp_purchase_lines_delete_operator on public.erp_purchase_lines
for delete to authenticated using (exists (
  select 1 from public.erp_purchase_documents d where d.id = document_id and d.status = 'draft'
    and public.erp_user_has_company_role(d.company_id, array['owner','admin','manager','operator','accountant']::text[])
));

drop policy if exists erp_sales_lines_select_member on public.erp_sales_lines;
create policy erp_sales_lines_select_member on public.erp_sales_lines
for select to authenticated using (exists (
  select 1 from public.erp_sales_documents d
  where d.id = document_id and public.erp_user_can_access_company(d.company_id)
));
drop policy if exists erp_sales_lines_insert_operator on public.erp_sales_lines;
create policy erp_sales_lines_insert_operator on public.erp_sales_lines
for insert to authenticated with check (exists (
  select 1 from public.erp_sales_documents d
  join public.erp_items i on i.id = item_id and i.company_id = d.company_id
  where d.id = document_id and d.status = 'draft'
    and public.erp_user_has_company_role(d.company_id, array['owner','admin','manager','operator','accountant']::text[])
));
drop policy if exists erp_sales_lines_update_operator on public.erp_sales_lines;
create policy erp_sales_lines_update_operator on public.erp_sales_lines
for update to authenticated using (exists (
  select 1 from public.erp_sales_documents d where d.id = document_id and d.status = 'draft'
    and public.erp_user_has_company_role(d.company_id, array['owner','admin','manager','operator','accountant']::text[])
)) with check (exists (
  select 1 from public.erp_sales_documents d
  join public.erp_items i on i.id = item_id and i.company_id = d.company_id
  where d.id = document_id and d.status = 'draft'
    and public.erp_user_has_company_role(d.company_id, array['owner','admin','manager','operator','accountant']::text[])
));
drop policy if exists erp_sales_lines_delete_operator on public.erp_sales_lines;
create policy erp_sales_lines_delete_operator on public.erp_sales_lines
for delete to authenticated using (exists (
  select 1 from public.erp_sales_documents d where d.id = document_id and d.status = 'draft'
    and public.erp_user_has_company_role(d.company_id, array['owner','admin','manager','operator','accountant']::text[])
));

grant select, insert, update, delete on public.erp_purchase_documents, public.erp_purchase_lines,
  public.erp_sales_documents, public.erp_sales_lines to authenticated;



-- Salary-bearing employee and payroll records are restricted to management/accounting.
drop policy if exists erp_employees_select_hr on public.erp_employees;
create policy erp_employees_select_hr on public.erp_employees
for select to authenticated
using (public.erp_user_has_company_role(company_id, array['owner','admin','manager','accountant']::text[]));
drop policy if exists erp_employees_insert_hr on public.erp_employees;
create policy erp_employees_insert_hr on public.erp_employees
for insert to authenticated
with check (public.erp_user_has_company_role(company_id, array['owner','admin','manager']::text[]));
drop policy if exists erp_employees_update_hr on public.erp_employees;
create policy erp_employees_update_hr on public.erp_employees
for update to authenticated
using (public.erp_user_has_company_role(company_id, array['owner','admin','manager']::text[]))
with check (public.erp_user_has_company_role(company_id, array['owner','admin','manager']::text[]));
drop policy if exists erp_employees_delete_hr on public.erp_employees;
create policy erp_employees_delete_hr on public.erp_employees
for delete to authenticated
using (public.erp_user_has_company_role(company_id, array['owner','admin']::text[]));

drop policy if exists erp_payroll_runs_select_accounting on public.erp_payroll_runs;
create policy erp_payroll_runs_select_accounting on public.erp_payroll_runs
for select to authenticated
using (public.erp_user_has_company_role(company_id, array['owner','admin','accountant']::text[]));
drop policy if exists erp_payroll_runs_insert_accounting on public.erp_payroll_runs;
create policy erp_payroll_runs_insert_accounting on public.erp_payroll_runs
for insert to authenticated
with check (public.erp_user_has_company_role(company_id, array['owner','admin','accountant']::text[]));
drop policy if exists erp_payroll_runs_update_accounting on public.erp_payroll_runs;
create policy erp_payroll_runs_update_accounting on public.erp_payroll_runs
for update to authenticated
using (status = 'draft' and public.erp_user_has_company_role(company_id, array['owner','admin','accountant']::text[]))
with check (public.erp_user_has_company_role(company_id, array['owner','admin','accountant']::text[]));
drop policy if exists erp_payroll_runs_delete_admin on public.erp_payroll_runs;
create policy erp_payroll_runs_delete_admin on public.erp_payroll_runs
for delete to authenticated
using (status = 'draft' and public.erp_user_has_company_role(company_id, array['owner','admin']::text[]));

-- Payroll lines inherit company scope from their payroll run and must reference
-- an employee in the same company.
drop policy if exists erp_payroll_lines_select_member on public.erp_payroll_lines;
create policy erp_payroll_lines_select_member on public.erp_payroll_lines
for select to authenticated using (exists (
  select 1 from public.erp_payroll_runs r
  where r.id = payroll_run_id and r.company_id = erp_payroll_lines.company_id
    and public.erp_user_can_access_company(r.company_id)
));
drop policy if exists erp_payroll_lines_insert_accounting on public.erp_payroll_lines;
create policy erp_payroll_lines_insert_accounting on public.erp_payroll_lines
for insert to authenticated with check (exists (
  select 1 from public.erp_payroll_runs r
  join public.erp_employees e on e.id = employee_id and e.company_id = r.company_id
  where r.id = payroll_run_id and r.company_id = erp_payroll_lines.company_id and r.status = 'draft'
    and public.erp_user_has_company_role(r.company_id, array['owner','admin','accountant']::text[])
));
drop policy if exists erp_payroll_lines_update_accounting on public.erp_payroll_lines;
create policy erp_payroll_lines_update_accounting on public.erp_payroll_lines
for update to authenticated using (exists (
  select 1 from public.erp_payroll_runs r
  where r.id = payroll_run_id and r.company_id = erp_payroll_lines.company_id and r.status = 'draft'
    and public.erp_user_has_company_role(r.company_id, array['owner','admin','accountant']::text[])
)) with check (exists (
  select 1 from public.erp_payroll_runs r
  join public.erp_employees e on e.id = employee_id and e.company_id = r.company_id
  where r.id = payroll_run_id and r.company_id = erp_payroll_lines.company_id and r.status = 'draft'
    and public.erp_user_has_company_role(r.company_id, array['owner','admin','accountant']::text[])
));
drop policy if exists erp_payroll_lines_delete_accounting on public.erp_payroll_lines;
create policy erp_payroll_lines_delete_accounting on public.erp_payroll_lines
for delete to authenticated using (exists (
  select 1 from public.erp_payroll_runs r
  where r.id = payroll_run_id and r.company_id = erp_payroll_lines.company_id and r.status = 'draft'
    and public.erp_user_has_company_role(r.company_id, array['owner','admin','accountant']::text[])
));

grant select, insert, update, delete on public.erp_employees, public.erp_attendance_records,
  public.erp_leave_requests, public.erp_payroll_runs, public.erp_payroll_lines,
  public.erp_cash_vouchers to authenticated;

