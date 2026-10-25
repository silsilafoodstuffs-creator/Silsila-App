-- Keep persisted permission keys aligned with the current ERP main-menu labels.
begin;

update public.erp_user_permission_matrix
set menu_name = case menu_name
  when 'إدارة البرنامج' then 'إعدادات عامة'
  when 'إدارة التطبيقات' then 'إدارة تطبيقات'
  when 'الحسابات المالية' then 'حسابات مالية'
  when 'المخازن والفروع' then 'مخازن'
  when 'المشتريات والموردون' then 'مشتريات'
  when 'المبيعات والعملاء' then 'مبيعات'
  when 'الموارد البشرية والرواتب' then 'موارد بشرية'
  when 'علاقات العملاء CRM' then 'علاقات عملاء'
  when 'الفاتورة الإلكترونية' then 'فاتورة إلكترونية'
  else menu_name end
where menu_name in (
  'إدارة البرنامج','إدارة التطبيقات','الحسابات المالية','المخازن والفروع',
  'المشتريات والموردون','المبيعات والعملاء','الموارد البشرية والرواتب',
  'علاقات العملاء CRM','الفاتورة الإلكترونية'
);

update public.erp_permission_template_rules
set menu_name = case menu_name
  when 'إدارة البرنامج' then 'إعدادات عامة'
  when 'إدارة التطبيقات' then 'إدارة تطبيقات'
  when 'الحسابات المالية' then 'حسابات مالية'
  when 'المخازن والفروع' then 'مخازن'
  when 'المشتريات والموردون' then 'مشتريات'
  when 'المبيعات والعملاء' then 'مبيعات'
  when 'الموارد البشرية والرواتب' then 'موارد بشرية'
  when 'علاقات العملاء CRM' then 'علاقات عملاء'
  when 'الفاتورة الإلكترونية' then 'فاتورة إلكترونية'
  else menu_name end
where menu_name in (
  'إدارة البرنامج','إدارة التطبيقات','الحسابات المالية','المخازن والفروع',
  'المشتريات والموردون','المبيعات والعملاء','الموارد البشرية والرواتب',
  'علاقات العملاء CRM','الفاتورة الإلكترونية'
);

commit;
