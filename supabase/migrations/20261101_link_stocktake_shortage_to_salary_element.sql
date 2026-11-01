alter table public.erp_stocktake_settlements
 add column if not exists salary_element_id uuid references public.erp_hr_salary_elements(id) on delete restrict;

create or replace function public.erp_link_stocktake_settlement_salary_element()
returns trigger language plpgsql security definer set search_path='' as $$
begin
 if new.target_type='employee' then
   select e.id into new.salary_element_id
   from public.erp_hr_salary_elements e
   where e.company_id=new.company_id and e.element_code='SYSSTOCKSHORTAGE'
     and e.is_system_locked=true and e.is_active=true
   limit 1;
   if new.salary_element_id is null then
     raise exception 'عنصر المرتب النظامي عجز جرد غير موجود أو غير نشط';
   end if;
 else
   new.salary_element_id:=null;
 end if;
 return new;
end $$;

drop trigger if exists trg_erp_link_stocktake_salary_element on public.erp_stocktake_settlements;
create trigger trg_erp_link_stocktake_salary_element
before insert or update of target_type,target_id,company_id
on public.erp_stocktake_settlements
for each row execute function public.erp_link_stocktake_settlement_salary_element();

create index if not exists erp_stocktake_settlements_salary_element_idx
on public.erp_stocktake_settlements(salary_element_id);
revoke all on function public.erp_link_stocktake_settlement_salary_element() from public,anon,authenticated;
