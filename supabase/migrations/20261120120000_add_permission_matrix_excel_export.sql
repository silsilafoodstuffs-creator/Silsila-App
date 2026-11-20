-- Keep the canonical per-screen permission matrix aligned with the ERP action catalog.
-- Safe for existing installations and repeatable.
alter table if exists public.erp_user_permission_matrix
  add column if not exists can_export_excel boolean not null default false;

alter table if exists public.erp_permission_template_rules
  add column if not exists can_export_excel boolean not null default false;
