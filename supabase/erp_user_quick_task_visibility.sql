-- Adds per-screen visibility control for the ERP quick-task area.
-- Safe to run on existing installations and repeat as needed.
alter table public.erp_user_permissions
  add column if not exists show_in_quick_tasks boolean not null default false;
