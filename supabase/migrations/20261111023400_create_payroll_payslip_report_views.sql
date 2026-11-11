create or replace view public.erp_v_employee_payslips
with (security_invoker = true)
as
select
  r.company_id,
  r.id as payroll_run_id,
  r.run_code,
  r.period_start,
  r.period_end,
  r.status as payroll_status,
  l.id as payroll_line_id,
  l.employee_id,
  e.employee_code,
  e.full_name as employee_name,
  e.branch_id,
  e.department_id,
  e.department_name,
  l.basic_amount,
  l.allowances,
  l.commissions,
  l.overtime_amount,
  l.deductions,
  l.gross_amount,
  l.net_amount,
  l.element_values,
  l.notes
from public.erp_payroll_runs r
join public.erp_payroll_lines l
  on l.payroll_run_id = r.id
 and l.company_id = r.company_id
join public.erp_employees e
  on e.id = l.employee_id
 and e.company_id = r.company_id
where r.status in ('approved', 'posted', 'paid');

create or replace view public.erp_v_payroll_payslip_summary
with (security_invoker = true)
as
select
  r.company_id,
  r.id as payroll_run_id,
  r.run_code,
  r.period_start,
  r.period_end,
  r.status as payroll_status,
  e.branch_id,
  e.department_id,
  e.department_name,
  count(l.id)::integer as employee_count,
  coalesce(sum(l.basic_amount), 0)::numeric(16,2) as basic_total,
  coalesce(sum(l.allowances), 0)::numeric(16,2) as allowances_total,
  coalesce(sum(l.commissions), 0)::numeric(16,2) as commissions_total,
  coalesce(sum(l.overtime_amount), 0)::numeric(16,2) as overtime_total,
  coalesce(sum(l.deductions), 0)::numeric(16,2) as deductions_total,
  coalesce(sum(l.gross_amount), 0)::numeric(16,2) as gross_total,
  coalesce(sum(l.net_amount), 0)::numeric(16,2) as net_total
from public.erp_payroll_runs r
join public.erp_payroll_lines l
  on l.payroll_run_id = r.id
 and l.company_id = r.company_id
join public.erp_employees e
  on e.id = l.employee_id
 and e.company_id = r.company_id
where r.status in ('approved', 'posted', 'paid')
group by r.company_id, r.id, r.run_code, r.period_start, r.period_end,
         r.status, e.branch_id, e.department_id, e.department_name;

grant select on public.erp_v_employee_payslips to authenticated;
grant select on public.erp_v_payroll_payslip_summary to authenticated;