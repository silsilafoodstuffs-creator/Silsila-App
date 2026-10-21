
-- Membership-aware HR permissions. Salary-bearing employee rows are limited to HR/finance roles.
drop policy if exists erp_employees_select_hr on public.erp_employees;
create policy erp_employees_select_hr on public.erp_employees for select to authenticated
using (public.erp_user_has_company_role(company_id, array['owner','admin','manager','accountant']::text[]));
drop policy if exists erp_employees_insert_hr on public.erp_employees;
create policy erp_employees_insert_hr on public.erp_employees for insert to authenticated
with check (public.erp_user_has_company_role(company_id, array['owner','admin','manager']::text[]));
drop policy if exists erp_employees_update_hr on public.erp_employees;
create policy erp_employees_update_hr on public.erp_employees for update to authenticated
using (public.erp_user_has_company_role(company_id, array['owner','admin','manager']::text[]))
with check (public.erp_user_has_company_role(company_id, array['owner','admin','manager']::text[]));
drop policy if exists erp_employees_delete_admin on public.erp_employees;
create policy erp_employees_delete_admin on public.erp_employees for delete to authenticated
using (public.erp_user_has_company_role(company_id, array['owner','admin']::text[]));

drop policy if exists erp_attendance_select_hr on public.erp_attendance_records;
create policy erp_attendance_select_hr on public.erp_attendance_records for select to authenticated
using (public.erp_user_has_company_role(company_id, array['owner','admin','manager','accountant','operator']::text[]));
drop policy if exists erp_attendance_insert_hr on public.erp_attendance_records;
create policy erp_attendance_insert_hr on public.erp_attendance_records for insert to authenticated
with check (public.erp_user_has_company_role(company_id, array['owner','admin','manager','operator']::text[]));
drop policy if exists erp_attendance_update_hr on public.erp_attendance_records;
create policy erp_attendance_update_hr on public.erp_attendance_records for update to authenticated
using (public.erp_user_has_company_role(company_id, array['owner','admin','manager']::text[]))
with check (public.erp_user_has_company_role(company_id, array['owner','admin','manager']::text[]));
drop policy if exists erp_attendance_delete_hr on public.erp_attendance_records;
create policy erp_attendance_delete_hr on public.erp_attendance_records for delete to authenticated
using (public.erp_user_has_company_role(company_id, array['owner','admin','manager']::text[]));

drop policy if exists erp_leave_select_hr on public.erp_leave_requests;
create policy erp_leave_select_hr on public.erp_leave_requests for select to authenticated
using (public.erp_user_has_company_role(company_id, array['owner','admin','manager','accountant','operator']::text[]));
drop policy if exists erp_leave_insert_hr on public.erp_leave_requests;
create policy erp_leave_insert_hr on public.erp_leave_requests for insert to authenticated
with check (public.erp_user_has_company_role(company_id, array['owner','admin','manager','operator']::text[]));
drop policy if exists erp_leave_update_hr on public.erp_leave_requests;
create policy erp_leave_update_hr on public.erp_leave_requests for update to authenticated
using (public.erp_user_has_company_role(company_id, array['owner','admin','manager']::text[]))
with check (public.erp_user_has_company_role(company_id, array['owner','admin','manager']::text[]));
drop policy if exists erp_leave_delete_hr on public.erp_leave_requests;
create policy erp_leave_delete_hr on public.erp_leave_requests for delete to authenticated
using (public.erp_user_has_company_role(company_id, array['owner','admin']::text[]));

drop policy if exists erp_payroll_runs_select_finance on public.erp_payroll_runs;
create policy erp_payroll_runs_select_finance on public.erp_payroll_runs for select to authenticated
using (public.erp_user_has_company_role(company_id, array['owner','admin','manager','accountant']::text[]));
drop policy if exists erp_payroll_runs_insert_finance on public.erp_payroll_runs;
create policy erp_payroll_runs_insert_finance on public.erp_payroll_runs for insert to authenticated
with check (public.erp_user_has_company_role(company_id, array['owner','admin','accountant']::text[]));
drop policy if exists erp_payroll_runs_update_finance on public.erp_payroll_runs;
create policy erp_payroll_runs_update_finance on public.erp_payroll_runs for update to authenticated
using (public.erp_user_has_company_role(company_id, array['owner','admin','accountant']::text[]))
with check (public.erp_user_has_company_role(company_id, array['owner','admin','accountant']::text[]));
drop policy if exists erp_payroll_runs_delete_draft on public.erp_payroll_runs;
create policy erp_payroll_runs_delete_draft on public.erp_payroll_runs for delete to authenticated
using (status = 'draft' and public.erp_user_has_company_role(company_id, array['owner','admin']::text[]));

drop policy if exists erp_payroll_lines_select_finance on public.erp_payroll_lines;
create policy erp_payroll_lines_select_finance on public.erp_payroll_lines for select to authenticated
using (public.erp_user_has_company_role(company_id, array['owner','admin','manager','accountant']::text[]));
drop policy if exists erp_payroll_lines_insert_finance on public.erp_payroll_lines;
create policy erp_payroll_lines_insert_finance on public.erp_payroll_lines for insert to authenticated
with check (public.erp_user_has_company_role(company_id, array['owner','admin','accountant']::text[]));
drop policy if exists erp_payroll_lines_update_finance on public.erp_payroll_lines;
create policy erp_payroll_lines_update_finance on public.erp_payroll_lines for update to authenticated
using (public.erp_user_has_company_role(company_id, array['owner','admin','accountant']::text[]))
with check (public.erp_user_has_company_role(company_id, array['owner','admin','accountant']::text[]));
drop policy if exists erp_payroll_lines_delete_finance on public.erp_payroll_lines;
create policy erp_payroll_lines_delete_finance on public.erp_payroll_lines for delete to authenticated
using (public.erp_user_has_company_role(company_id, array['owner','admin','accountant']::text[]));

grant select, insert, update, delete on public.erp_employees, public.erp_attendance_records,
  public.erp_leave_requests, public.erp_payroll_runs, public.erp_payroll_lines to authenticated;

create or replace view public.erp_employee_directory with (security_barrier = true) as
select e.id,e.company_id,e.branch_id,e.employee_code,e.full_name,e.phone,e.email,
       e.job_title,e.department_name,e.hire_date,e.employment_status,e.is_active
from public.erp_employees e
where public.erp_user_can_access_company(e.company_id) and e.is_active = true;

revoke all on public.erp_employee_directory from anon, public;
grant select on public.erp_employee_directory to authenticated;
revoke all on function public.erp_validate_hr_company_links() from public, anon, authenticated;

create or replace view public.erp_employee_directory with (security_invoker = true) as
select e.id,e.company_id,e.branch_id,e.employee_code,e.full_name,e.phone,e.email,
       e.job_title,e.department_name,e.hire_date,e.employment_status,e.is_active
from public.erp_employees e
where public.erp_user_can_access_company(e.company_id) and e.is_active = true;

create or replace function public.erp_decide_leave_request(p_request_id uuid, p_decision text)
returns void language plpgsql security definer set search_path = public set row_security = off as $$
declare v_company_id uuid; v_status text;
begin
  if auth.uid() is null then raise exception 'يجب تسجيل الدخول أولًا'; end if;
  if p_decision not in ('approved','rejected','cancelled') then raise exception 'قرار الإجازة غير مدعوم'; end if;
  select company_id,status into v_company_id,v_status from public.erp_leave_requests where id=p_request_id for update;
  if not found then raise exception 'طلب الإجازة غير موجود'; end if;
  if not public.erp_user_has_company_role(v_company_id,array['owner','admin','manager']::text[]) then
    raise exception 'ليست لديك صلاحية اتخاذ قرار بشأن الإجازة';
  end if;
  if v_status <> 'pending' then raise exception 'لا يمكن تعديل طلب إجازة إلا إذا كان معلقًا'; end if;
  update public.erp_leave_requests
  set status=p_decision,
      approved_by=case when p_decision in ('approved','rejected') then auth.uid() else null end,
      approved_at=case when p_decision in ('approved','rejected') then now() else null end,
      updated_at=now()
  where id=p_request_id;
end;
$$;
revoke all on function public.erp_decide_leave_request(uuid,text) from public, anon;
grant execute on function public.erp_decide_leave_request(uuid,text) to authenticated;
