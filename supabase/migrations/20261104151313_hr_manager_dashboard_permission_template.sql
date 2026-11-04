-- HR executive dashboard permission template and automatic assignment by job title.
alter table public.erp_company_member_profiles
  add column if not exists permission_template_id uuid
  references public.erp_permission_templates(id) on delete set null;

insert into public.erp_permission_templates
  (company_id, name_ar, name_en, is_active)
select c.id, 'مدير موارد بشرية', 'HR Manager', true
from public.erp_companies c
on conflict (company_id, name_ar)
do update set name_en = excluded.name_en, is_active = true;

insert into public.erp_permission_template_rules
  (company_id, template_id, menu_name, submenu_name, page_name,
   can_access, can_refresh, can_add, can_save, can_edit, can_delete,
   can_preview, can_print, can_import_excel, can_print_pdf, show_in_quick_tasks)
select t.company_id, t.id, 'موارد بشرية', 'بيانات أساسية',
       'ملخص إدارة موارد بشرية',
       true, true, false, false, false, false, true, true, false, true, false
from public.erp_permission_templates t
where t.name_ar = 'مدير موارد بشرية'
on conflict (template_id, menu_name, submenu_name, page_name)
do update set can_access = true, can_refresh = true, can_preview = true,
              can_print = true, can_print_pdf = true;

create or replace function public.erp_assign_hr_manager_permission_template()
returns trigger
language plpgsql
set search_path = public
as $$
begin
  if trim(coalesce(new.job_title, '')) = 'مدير موارد بشرية' then
    select t.id into new.permission_template_id
    from public.erp_permission_templates t
    where t.company_id = new.company_id
      and t.name_ar = 'مدير موارد بشرية'
      and t.is_active = true
    limit 1;
  elsif trim(coalesce(new.job_title, '')) in ('مسئول موارد بشرية', 'مسؤول موارد بشرية') then
    new.permission_template_id := null;
  end if;
  return new;
end;
$$;

drop trigger if exists erp_company_member_profiles_hr_template_trigger
  on public.erp_company_member_profiles;
create trigger erp_company_member_profiles_hr_template_trigger
before insert or update of job_title, company_id
on public.erp_company_member_profiles
for each row
execute function public.erp_assign_hr_manager_permission_template();

update public.erp_company_member_profiles p
set permission_template_id = t.id
from public.erp_permission_templates t
where p.company_id = t.company_id
  and t.name_ar = 'مدير موارد بشرية'
  and t.is_active = true
  and trim(coalesce(p.job_title, '')) = 'مدير موارد بشرية'
  and p.permission_template_id is distinct from t.id;
