begin;
alter table public.erp_hr_departments
  add column if not exists work_location_id uuid references public.erp_hr_work_locations(id) on delete set null;
update public.erp_hr_departments d
set work_location_id = (
  select l.id from public.erp_hr_work_locations l
  where l.company_id = d.company_id and l.location_type = 'central' and l.is_active = true
  order by l.location_code limit 1
)
where d.work_location_id is null;
create index if not exists erp_hr_departments_location_idx
  on public.erp_hr_departments(company_id, work_location_id, department_code);
commit;
