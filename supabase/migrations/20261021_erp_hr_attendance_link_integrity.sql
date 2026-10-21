
alter table public.erp_hr_shift_assignments add constraint erp_hr_shift_assignments_employee_fk foreign key (employee_id) references public.erp_employees(id) on delete restrict;
alter table public.erp_hr_attendance_events add constraint erp_hr_attendance_events_employee_fk foreign key (employee_id) references public.erp_employees(id) on delete set null;
create or replace function public.erp_validate_hr_attendance_links()
returns trigger language plpgsql security definer set search_path = public set row_security = off as $$
declare v_company_id uuid;
begin
  if tg_table_name in ('erp_hr_shifts','erp_hr_fingerprint_devices') then
    if new.branch_id is not null then
      select company_id into v_company_id from public.erp_branches where id=new.branch_id;
      if v_company_id is distinct from new.company_id then raise exception 'الفرع يجب أن يتبع الشركة نفسها في إعدادات الحضور'; end if;
    end if;
  elsif tg_table_name='erp_hr_shift_assignments' then
    select company_id into v_company_id from public.erp_hr_shifts where id=new.shift_id;
    if v_company_id is distinct from new.company_id then raise exception 'الوردية يجب أن تتبع الشركة نفسها'; end if;
    select company_id into v_company_id from public.erp_employees where id=new.employee_id;
    if v_company_id is distinct from new.company_id then raise exception 'الموظف يجب أن يتبع الشركة نفسها'; end if;
    if new.branch_id is not null then
      select company_id into v_company_id from public.erp_branches where id=new.branch_id;
      if v_company_id is distinct from new.company_id then raise exception 'فرع التعيين يجب أن يتبع الشركة نفسها'; end if;
    end if;
  elsif tg_table_name='erp_hr_attendance_events' then
    if new.device_id is not null then
      select company_id into v_company_id from public.erp_hr_fingerprint_devices where id=new.device_id;
      if v_company_id is distinct from new.company_id then raise exception 'جهاز البصمة يجب أن يتبع الشركة نفسها'; end if;
    end if;
    if new.employee_id is not null then
      select company_id into v_company_id from public.erp_employees where id=new.employee_id;
      if v_company_id is distinct from new.company_id then raise exception 'الموظف يجب أن يتبع الشركة نفسها في حدث البصمة'; end if;
    end if;
  end if;
  return new;
end;
$$;
revoke all on function public.erp_validate_hr_attendance_links() from public,anon,authenticated;
drop trigger if exists erp_hr_shift_company_guard on public.erp_hr_shifts;
create trigger erp_hr_shift_company_guard before insert or update of company_id,branch_id on public.erp_hr_shifts for each row execute function public.erp_validate_hr_attendance_links();
drop trigger if exists erp_hr_device_company_guard on public.erp_hr_fingerprint_devices;
create trigger erp_hr_device_company_guard before insert or update of company_id,branch_id on public.erp_hr_fingerprint_devices for each row execute function public.erp_validate_hr_attendance_links();
drop trigger if exists erp_hr_assignment_company_guard on public.erp_hr_shift_assignments;
create trigger erp_hr_assignment_company_guard before insert or update of company_id,shift_id,employee_id,branch_id on public.erp_hr_shift_assignments for each row execute function public.erp_validate_hr_attendance_links();
drop trigger if exists erp_hr_event_company_guard on public.erp_hr_attendance_events;
create trigger erp_hr_event_company_guard before insert or update of company_id,device_id,employee_id on public.erp_hr_attendance_events for each row execute function public.erp_validate_hr_attendance_links();
