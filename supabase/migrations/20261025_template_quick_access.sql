alter table if exists public.erp_permission_template_rules add column if not exists show_in_quick_tasks boolean not null default false;
