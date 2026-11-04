create or replace function public.erp_hr_apply_employee_movement()
returns trigger language plpgsql set search_path=public as $$
begin
  if new.movement_type in ('resignation','termination','retirement') then
    update public.erp_employees set is_active=false, employment_status='terminated', updated_at=now()
     where id=new.employee_id and company_id=new.company_id;
  elsif new.movement_type='return_to_work' then
    update public.erp_employees set is_active=true, employment_status='active', updated_at=now()
     where id=new.employee_id and company_id=new.company_id;
  end if;
  return new;
end;
$$;