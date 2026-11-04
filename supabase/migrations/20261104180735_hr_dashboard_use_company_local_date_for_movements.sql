create or replace function public.erp_hr_apply_employee_movement()
returns trigger
language plpgsql
set search_path = public
as $$
declare
  today_local date := (now() at time zone 'Africa/Cairo')::date;
  latest_effective_date date;
begin
  if new.effective_on > today_local then return new; end if;
  select max(m.effective_on) into latest_effective_date
    from public.erp_hr_employee_movements m
   where m.company_id = new.company_id and m.employee_id = new.employee_id
     and m.effective_on <= today_local;
  if latest_effective_date is distinct from new.effective_on then return new; end if;
  if new.movement_type in ('resignation','termination','retirement') then
    update public.erp_employees set is_active=false, employment_status='terminated', updated_at=now()
     where id=new.employee_id and company_id=new.company_id;
  elsif new.movement_type in ('return_to_work','hire') then
    update public.erp_employees set is_active=true, employment_status='active', updated_at=now()
     where id=new.employee_id and company_id=new.company_id;
  elsif new.movement_type='suspension' then
    update public.erp_employees set is_active=true, employment_status='suspended', updated_at=now()
     where id=new.employee_id and company_id=new.company_id;
  end if;
  return new;
end;
$$;