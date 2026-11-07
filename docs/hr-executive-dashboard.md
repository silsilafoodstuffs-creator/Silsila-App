# HR Executive Dashboard

The HR Executive Summary is available under **موارد بشرية → بيانات أساسية → ملخص إدارة موارد بشرية**.

## Access model

- The **مدير موارد بشرية** job title receives the **مدير موارد بشرية** permission template automatically.
- The profile trigger re-evaluates the template when the job title, company, or template assignment changes.
- Changing the job title away from **مدير موارد بشرية** removes this specific template.
- **مسئول موارد بشرية** and **مسؤول موارد بشرية** are explicitly excluded from the dashboard route.
- Company owners and admins can review and manage the dashboard. Users with an explicit read permission but without the HR-manager role receive a read-only dashboard.
- HR source-table policies permit company owners/admins/managers and the exact HR-manager job title; profile self-read is limited to the signed-in member's own profile.

## Dashboard data sources

| Area | Source |
| --- | --- |
| Employees, contract dates, job assignment | `erp_employees` |
| Departments and jobs | `erp_hr_departments`, `erp_hr_jobs` |
| Approved authorized headcount and calculated vacancies | `erp_hr_staffing_plans` |
| Work locations used to scope a staffing plan | `erp_hr_work_locations` |
| Supporting appointment documents | `erp_employee_documents` |
| Attendance and overtime | `erp_attendance_records` |
| Leave requests | `erp_leave_requests` |
| Payroll run approval status | `erp_payroll_runs` |
| Health/social insurance and licenses | `erp_hr_employee_compliance` |
| Training and certificate validity | `erp_hr_training_records` |
| Recruitment pipeline | `erp_hr_recruitment_candidates` |
| Hiring, transfer, resignation and termination movements | `erp_hr_employee_movements` |

## Operating the dashboard

Authorized HR managers can add draft or pending-approval staffing plans, compliance/license records, training records, candidates, and employee movements. Company owners/admins approve staffing plans; approval is enforced by database policy and a trigger, not by a client-side button alone. A plan must match a job and optional work location in the same company. Overlapping approved plans for the same job/location scope are rejected.

Dates entered in the dashboard use **DD-MM-YYYY**; dates are stored as ISO date values in PostgreSQL.

## Metric interpretation

- Contract alerts use the employee contract start/end fields and active status.
- Appointment-document gaps compare each employee's assigned job requirements with the employee's recorded document types.
- Vacancy counts are calculated only from approved staffing plans whose effective date range includes today. Draft and pending plans are excluded. A company-wide plan cannot overlap a location-specific plan for the same job and period. The number of filled positions is capped at the authorized headcount for that plan; over-capacity is displayed separately.
- Insurance, license, training, and recruitment metrics count the records actually stored in their respective tables; they do not fabricate missing records.
- Absence, lateness, overtime, leave, and payroll indicators use the existing operational tables.
- Turnover is an estimate derived from recorded employee movements and available hire dates. It is shown as unavailable when no movement history exists.
- Historical turnover accuracy depends on backfilling historical hires and separations. A company with empty new HR tables must enter its records before those indicators become meaningful.

## Database security

HR source tables have row-level security enabled and anonymous table privileges revoked. Employee SELECT/UPDATE policies target authenticated users and retain company-role checks. Staffing plans are readable by company members and writable by authorized company managers or the exact **مدير موارد بشرية** job title; only company owners/admins can approve or modify an already approved plan. The public profile directory is a read-only projection for approved marketplace participants and excludes platform-management accounts. The employee-movement trigger behavior remains governed by its existing implementation.

## First-use checklist

1. Create or complete the company member profile for the person who will manage HR.
2. Set the job title exactly to **مدير موارد بشرية**. The database trigger assigns the company HR-manager template.
3. Confirm that the dashboard appears for that member and remains hidden for members titled **مسئول موارد بشرية** or **مسؤول موارد بشرية**.
4. Create staffing plans for each job and work location, submit them for approval, and have a company owner/admin approve them. Vacancies remain unavailable until an approved plan is effective.
5. Enter real insurance, license, training, recruitment, and employee-movement records. New HR tables intentionally start empty; the dashboard does not seed invented statuses.
6. Recheck the dashboard after each entry. Contract and appointment-document indicators continue to use the existing employee and document records.
