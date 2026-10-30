-- Link sales representatives directly to HR employees and configure target/commission flags.
alter table public.erp_sales_representatives
  add column if not exists employee_id uuid references public.erp_employees(id) on delete set null,
  add column if not exists has_target boolean not null default false,
  add column if not exists has_commission boolean not null default false,
  add column if not exists commission_type text not null default 'percentage';

alter table public.erp_sales_representatives
  drop constraint if exists erp_sales_representatives_commission_type_check;
alter table public.erp_sales_representatives
  add constraint erp_sales_representatives_commission_type_check
  check (commission_type in ('tiered','percentage','points_per_unit'));

create unique index if not exists erp_sales_representatives_company_employee_uidx
  on public.erp_sales_representatives(company_id, employee_id);

insert into public.erp_sales_representatives
  (company_id, employee_id, rep_code, rep_name, is_active, has_target, has_commission, commission_type, commission_plan, is_demo_data)
select e.company_id, e.id,
       'REP-' || coalesce(nullif(substring(e.employee_code from '([0-9]+)$'),''), upper(regexp_replace(e.employee_code,'[^A-Za-z0-9]','','g'))),
       e.full_name, e.is_active, false, false, 'percentage', 'percentage', false
from public.erp_employees e
where e.department_name ilike '%مبيعات%'
on conflict (company_id, employee_id) do nothing;
