
-- Membership-aware permissions for shift rules and fingerprint device configuration.
drop policy if exists erp_hr_shifts_select_member on public.erp_hr_shifts;
create policy erp_hr_shifts_select_member on public.erp_hr_shifts for select to authenticated using (public.erp_user_can_access_company(company_id));
drop policy if exists erp_hr_shifts_insert_manager on public.erp_hr_shifts;
create policy erp_hr_shifts_insert_manager on public.erp_hr_shifts for insert to authenticated with check (public.erp_user_has_company_role(company_id,array['owner','admin','manager']::text[]));
drop policy if exists erp_hr_shifts_update_manager on public.erp_hr_shifts;
create policy erp_hr_shifts_update_manager on public.erp_hr_shifts for update to authenticated using (public.erp_user_has_company_role(company_id,array['owner','admin','manager']::text[])) with check (public.erp_user_has_company_role(company_id,array['owner','admin','manager']::text[]));
drop policy if exists erp_hr_shifts_delete_manager on public.erp_hr_shifts;
create policy erp_hr_shifts_delete_manager on public.erp_hr_shifts for delete to authenticated using (public.erp_user_has_company_role(company_id,array['owner','admin','manager']::text[]));
drop policy if exists erp_hr_shift_assignments_select_member on public.erp_hr_shift_assignments;
create policy erp_hr_shift_assignments_select_member on public.erp_hr_shift_assignments for select to authenticated using (public.erp_user_can_access_company(company_id));
drop policy if exists erp_hr_shift_assignments_insert_manager on public.erp_hr_shift_assignments;
create policy erp_hr_shift_assignments_insert_manager on public.erp_hr_shift_assignments for insert to authenticated with check (public.erp_user_has_company_role(company_id,array['owner','admin','manager']::text[]));
drop policy if exists erp_hr_shift_assignments_update_manager on public.erp_hr_shift_assignments;
create policy erp_hr_shift_assignments_update_manager on public.erp_hr_shift_assignments for update to authenticated using (public.erp_user_has_company_role(company_id,array['owner','admin','manager']::text[])) with check (public.erp_user_has_company_role(company_id,array['owner','admin','manager']::text[]));
drop policy if exists erp_hr_shift_assignments_delete_manager on public.erp_hr_shift_assignments;
create policy erp_hr_shift_assignments_delete_manager on public.erp_hr_shift_assignments for delete to authenticated using (public.erp_user_has_company_role(company_id,array['owner','admin','manager']::text[]));
drop policy if exists erp_hr_devices_select_manager on public.erp_hr_fingerprint_devices;
create policy erp_hr_devices_select_manager on public.erp_hr_fingerprint_devices for select to authenticated using (public.erp_user_has_company_role(company_id,array['owner','admin','manager']::text[]));
drop policy if exists erp_hr_devices_insert_manager on public.erp_hr_fingerprint_devices;
create policy erp_hr_devices_insert_manager on public.erp_hr_fingerprint_devices for insert to authenticated with check (public.erp_user_has_company_role(company_id,array['owner','admin','manager']::text[]));
drop policy if exists erp_hr_devices_update_manager on public.erp_hr_fingerprint_devices;
create policy erp_hr_devices_update_manager on public.erp_hr_fingerprint_devices for update to authenticated using (public.erp_user_has_company_role(company_id,array['owner','admin','manager']::text[])) with check (public.erp_user_has_company_role(company_id,array['owner','admin','manager']::text[]));
drop policy if exists erp_hr_devices_delete_manager on public.erp_hr_fingerprint_devices;
create policy erp_hr_devices_delete_manager on public.erp_hr_fingerprint_devices for delete to authenticated using (public.erp_user_has_company_role(company_id,array['owner','admin','manager']::text[]));
drop policy if exists erp_hr_events_select_hr on public.erp_hr_attendance_events;
create policy erp_hr_events_select_hr on public.erp_hr_attendance_events for select to authenticated using (public.erp_user_has_company_role(company_id,array['owner','admin','manager','accountant']::text[]));
grant select,insert,update,delete on public.erp_hr_shifts,public.erp_hr_shift_assignments,public.erp_hr_fingerprint_devices to authenticated;
grant select on public.erp_hr_attendance_events to authenticated;
create index if not exists erp_hr_shift_branch_idx on public.erp_hr_shifts(branch_id);
create index if not exists erp_hr_assignment_shift_fk_idx on public.erp_hr_shift_assignments(shift_id);
create index if not exists erp_hr_assignment_employee_fk_idx on public.erp_hr_shift_assignments(employee_id);
create index if not exists erp_hr_assignment_branch_fk_idx on public.erp_hr_shift_assignments(branch_id);
create index if not exists erp_hr_device_branch_fk_idx on public.erp_hr_fingerprint_devices(branch_id);
create index if not exists erp_hr_event_device_fk_idx on public.erp_hr_attendance_events(device_id);
create index if not exists erp_hr_event_employee_idx on public.erp_hr_attendance_events(employee_id);

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
