-- Store full Egyptian national ID only in the restricted HR table and enforce the admin policy server-side.
alter table public.erp_employees
  add column if not exists national_id text;

alter table public.erp_employees
  drop constraint if exists erp_employees_national_id_format_check;
alter table public.erp_employees
  add constraint erp_employees_national_id_format_check
  check (national_id is null or national_id ~ '^[0-9]{14}$');

create unique index if not exists erp_employees_company_national_id_uidx
  on public.erp_employees(company_id, national_id)
  where national_id is not null;

create or replace function public.erp_enforce_employee_national_id_policy()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if new.national_id is not null then
    new.national_id := btrim(new.national_id);
    if new.national_id !~ '^[0-9]{14}$' then
      raise exception 'الرقم القومي يجب أن يتكون من 14 رقمًا.';
    end if;
    new.national_id_last4 := right(new.national_id, 4);
  end if;

  if tg_op = 'INSERT'
     and public.erp_program_policy_applies(new.company_id, 'national_id_required', auth.uid())
     and coalesce(new.national_id, '') = '' then
    raise exception 'سياسة البرنامج تشترط تسجيل الرقم القومي المكوّن من 14 رقمًا للموظف الجديد.';
  end if;
  return new;
end;
$$;

drop trigger if exists erp_employee_national_id_policy_guard on public.erp_employees;
create trigger erp_employee_national_id_policy_guard
before insert or update of national_id
on public.erp_employees
for each row execute function public.erp_enforce_employee_national_id_policy();
