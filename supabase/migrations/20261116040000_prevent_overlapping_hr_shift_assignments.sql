begin;

create or replace function public.erp_guard_hr_shift_assignment_overlap()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  if exists (
    select 1
    from public.erp_hr_shift_assignments a
    where a.company_id = new.company_id
      and a.employee_id = new.employee_id
      and a.id is distinct from new.id
      and daterange(a.effective_from, coalesce(a.effective_to, 'infinity'::date), '[]')
          && daterange(new.effective_from, coalesce(new.effective_to, 'infinity'::date), '[]')
  ) then
    raise exception 'الموظف لديه توزيع وردية آخر يتداخل مع الفترة المحددة';
  end if;
  return new;
end;
$$;

drop trigger if exists erp_hr_shift_assignment_overlap_guard on public.erp_hr_shift_assignments;
create trigger erp_hr_shift_assignment_overlap_guard
before insert or update of company_id, employee_id, shift_id, effective_from, effective_to
on public.erp_hr_shift_assignments
for each row execute function public.erp_guard_hr_shift_assignment_overlap();

commit;
