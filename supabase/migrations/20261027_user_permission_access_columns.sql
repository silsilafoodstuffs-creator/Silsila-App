alter table public.erp_permission_template_rules
  add column if not exists can_access boolean not null default false,
  add column if not exists show_in_quick_tasks boolean not null default false;
alter table public.erp_user_permission_matrix
  add column if not exists can_access boolean not null default false,
  add column if not exists show_in_quick_tasks boolean not null default false;