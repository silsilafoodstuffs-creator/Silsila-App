-- Remove redundant display-code indexes already provided by the user-management schema.
drop index if exists public.erp_user_types_display_code_uidx;
drop index if exists public.erp_permission_templates_display_code_uidx;
