begin;

create or replace function public.erp_user_can_manage_hr_shift(
  p_company_id uuid,
  p_branch_id uuid default null
)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1
    from public.erp_company_member_profiles p
    join public.erp_permission_templates t
      on t.id = p.permission_template_id
     and t.company_id = p.company_id
     and t.is_active = true
    join public.erp_permission_template_rules r
      on r.company_id = p.company_id
     and r.template_id = t.id
     and r.menu_name = 'موارد بشرية'
     and r.page_name = 'الورديات وجداول العمل'
     and r.can_access = true
     and r.can_add = true
     and r.can_edit = true
    where p.company_id = p_company_id
      and p.user_id = auth.uid()
      and (p.branch_id is null or p.branch_id = p_branch_id)
  );
$$;

revoke all on function public.erp_user_can_manage_hr_shift(uuid, uuid) from public, anon;
grant execute on function public.erp_user_can_manage_hr_shift(uuid, uuid) to authenticated;

drop policy if exists erp_scope_guard_erp_hr_shifts on public.erp_hr_shifts;
create policy erp_scope_guard_erp_hr_shifts
on public.erp_hr_shifts
as restrictive
for all
to authenticated
using (
  (branch_id is null and public.erp_user_can_access_company(company_id))
  or (branch_id is not null and public.erp_user_can_access_branch_scope(company_id, branch_id))
  or public.erp_user_can_manage_hr_shift(company_id, branch_id)
)
with check (
  (branch_id is null and public.erp_user_can_access_company(company_id))
  or (branch_id is not null and public.erp_user_can_access_branch_scope(company_id, branch_id))
  or public.erp_user_can_manage_hr_shift(company_id, branch_id)
);

drop policy if exists erp_hr_shifts_insert_manager on public.erp_hr_shifts;
create policy erp_hr_shifts_insert_manager
on public.erp_hr_shifts
for insert
to authenticated
with check (
  public.erp_user_has_company_role(company_id, array['owner','admin','manager']::text[])
  or public.erp_user_can_manage_hr_shift(company_id, branch_id)
);

drop policy if exists erp_hr_shifts_update_manager on public.erp_hr_shifts;
create policy erp_hr_shifts_update_manager
on public.erp_hr_shifts
for update
to authenticated
using (
  public.erp_user_has_company_role(company_id, array['owner','admin','manager']::text[])
  or public.erp_user_can_manage_hr_shift(company_id, branch_id)
)
with check (
  public.erp_user_has_company_role(company_id, array['owner','admin','manager']::text[])
  or public.erp_user_can_manage_hr_shift(company_id, branch_id)
);

drop policy if exists erp_hr_shifts_delete_manager on public.erp_hr_shifts;
create policy erp_hr_shifts_delete_manager
on public.erp_hr_shifts
for delete
to authenticated
using (
  public.erp_user_has_company_role(company_id, array['owner','admin','manager']::text[])
  or public.erp_user_can_manage_hr_shift(company_id, branch_id)
);

drop policy if exists erp_scope_guard_erp_hr_shift_assignments on public.erp_hr_shift_assignments;
create policy erp_scope_guard_erp_hr_shift_assignments
on public.erp_hr_shift_assignments
as restrictive
for all
to authenticated
using (
  employee_id is not null
  and (
    (branch_id is not null and (
      public.erp_user_can_access_branch_scope(company_id, branch_id)
      or public.erp_user_can_manage_hr_shift(company_id, branch_id)
    ))
    or (branch_id is null and (
      public.erp_user_can_access_employee_scope(company_id, employee_id)
      or public.erp_user_can_manage_hr_shift(company_id, null)
    ))
  )
  and (
    public.erp_user_can_access_employee_scope(company_id, employee_id)
    or public.erp_user_can_manage_hr_shift(company_id, branch_id)
  )
)
with check (
  employee_id is not null
  and (
    (branch_id is not null and (
      public.erp_user_can_access_branch_scope(company_id, branch_id)
      or public.erp_user_can_manage_hr_shift(company_id, branch_id)
    ))
    or (branch_id is null and (
      public.erp_user_can_access_employee_scope(company_id, employee_id)
      or public.erp_user_can_manage_hr_shift(company_id, null)
    ))
  )
  and (
    public.erp_user_can_access_employee_scope(company_id, employee_id)
    or public.erp_user_can_manage_hr_shift(company_id, branch_id)
  )
);

drop policy if exists erp_hr_shift_assignments_insert_manager on public.erp_hr_shift_assignments;
create policy erp_hr_shift_assignments_insert_manager
on public.erp_hr_shift_assignments
for insert
to authenticated
with check (
  public.erp_user_has_company_role(company_id, array['owner','admin','manager']::text[])
  or public.erp_user_can_manage_hr_shift(company_id, branch_id)
);

drop policy if exists erp_hr_shift_assignments_update_manager on public.erp_hr_shift_assignments;
create policy erp_hr_shift_assignments_update_manager
on public.erp_hr_shift_assignments
for update
to authenticated
using (
  public.erp_user_has_company_role(company_id, array['owner','admin','manager']::text[])
  or public.erp_user_can_manage_hr_shift(company_id, branch_id)
)
with check (
  public.erp_user_has_company_role(company_id, array['owner','admin','manager']::text[])
  or public.erp_user_can_manage_hr_shift(company_id, branch_id)
);

drop policy if exists erp_hr_shift_assignments_delete_manager on public.erp_hr_shift_assignments;
create policy erp_hr_shift_assignments_delete_manager
on public.erp_hr_shift_assignments
for delete
to authenticated
using (
  public.erp_user_has_company_role(company_id, array['owner','admin','manager']::text[])
  or public.erp_user_can_manage_hr_shift(company_id, branch_id)
);

commit;
