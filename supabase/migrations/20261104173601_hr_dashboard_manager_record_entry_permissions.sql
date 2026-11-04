update public.erp_permission_template_rules r
set can_add=true, can_save=true
from public.erp_permission_templates t
where r.template_id=t.id
  and t.name_ar='مدير موارد بشرية'
  and r.menu_name='موارد بشرية'
  and r.submenu_name='بيانات أساسية'
  and r.page_name='ملخص إدارة موارد بشرية';
