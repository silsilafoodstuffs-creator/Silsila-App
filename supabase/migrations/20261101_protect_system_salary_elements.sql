-- Protect system-owned payroll elements from direct API/SQL updates and deletes.
-- In particular, SYSSTOCKSHORTAGE is a mandatory system deduction used by stocktake workflows.
create or replace function public.erp_guard_system_salary_elements()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  if old.is_system_locked is true or old.element_code = 'SYSSTOCKSHORTAGE' then
    raise exception 'هذا عنصر مرتبات نظامي محمي ولا يسمح بتعديله أو حذفه'
      using errcode = '55000';
  end if;
  return case when tg_op = 'DELETE' then old else new end;
end;
$$;

drop trigger if exists trg_erp_guard_system_salary_elements on public.erp_hr_salary_elements;
create trigger trg_erp_guard_system_salary_elements
before update or delete on public.erp_hr_salary_elements
for each row execute function public.erp_guard_system_salary_elements();
