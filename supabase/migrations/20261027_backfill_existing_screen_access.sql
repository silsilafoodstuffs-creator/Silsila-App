update public.erp_permission_template_rules
set can_access=true
where can_access=false and (
  can_refresh or can_add or can_save or can_edit or can_delete or can_preview or can_print or can_import_excel or can_print_pdf
);
update public.erp_user_permission_matrix
set can_access=true
where can_access=false and (
  can_refresh or can_add or can_save or can_edit or can_delete or can_preview or can_print or can_import_excel or can_print_pdf
);