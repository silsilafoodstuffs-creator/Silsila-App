drop trigger if exists erp_hr_employee_custodies_company_link on public.erp_hr_employee_custodies;
create trigger erp_hr_employee_custodies_company_link
before insert or update of company_id, employee_id on public.erp_hr_employee_custodies
for each row execute function public.erp_hr_validate_company_links();

drop trigger if exists erp_hr_employee_custodies_updated_at on public.erp_hr_employee_custodies;
create trigger erp_hr_employee_custodies_updated_at
before update on public.erp_hr_employee_custodies
for each row execute function public.erp_set_updated_at();