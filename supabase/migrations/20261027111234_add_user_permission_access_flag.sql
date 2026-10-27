begin;

alter table public.erp_user_permission_matrix
  add column if not exists can_access boolean not null default false;

update public.erp_user_permission_matrix
set can_access = (
  can_refresh or can_add or can_save or can_edit or can_delete or
  can_preview or can_print or can_import_excel or can_print_pdf or show_in_quick_tasks
)
where can_access = false;

commit;
