begin;
with manager_template as (
  select id,company_id from public.erp_permission_templates
  where name_ar='مدير موارد بشرية' and is_active=true
), hr_pages(submenu_name,page_name,can_add,can_save,can_edit,can_delete,can_preview,can_print,can_import_excel,can_print_pdf) as (
  values
  ('بيانات أساسية','الهيكل الوظيفي',1,1,1,0,1,1,1,1),
  ('حركات','سلف الموظفين',1,1,1,0,1,1,0,1),
  ('تقارير','تقرير الحضور',0,0,0,0,1,1,0,1),
  ('تقارير','تقرير الإجازات',0,0,0,0,1,1,0,1),
  ('تقارير','تقرير التدريب',0,0,0,0,1,1,0,1),
  ('تقارير','التأمينات والتراخيص',0,0,0,0,1,1,0,1),
  ('تقارير','كشف الرواتب',0,0,0,0,1,1,0,1)
)
insert into public.erp_permission_template_rules(
 company_id,template_id,menu_name,submenu_name,page_name,
 can_refresh,can_add,can_save,can_edit,can_delete,can_preview,can_print,can_import_excel,can_print_pdf,can_access,show_in_quick_tasks
)
select mt.company_id,mt.id,'موارد بشرية',hp.submenu_name,hp.page_name,
 true,hp.can_add=1,hp.can_save=1,hp.can_edit=1,hp.can_delete=1,
 hp.can_preview=1,hp.can_print=1,hp.can_import_excel=1,hp.can_print_pdf=1,true,false
from manager_template mt cross join hr_pages hp
on conflict (template_id,menu_name,submenu_name,page_name)
do update set
 can_refresh=excluded.can_refresh,can_add=excluded.can_add,can_save=excluded.can_save,
 can_edit=excluded.can_edit,can_delete=excluded.can_delete,can_preview=excluded.can_preview,
 can_print=excluded.can_print,can_import_excel=excluded.can_import_excel,
 can_print_pdf=excluded.can_print_pdf,can_access=excluded.can_access,
 show_in_quick_tasks=excluded.show_in_quick_tasks;
commit;