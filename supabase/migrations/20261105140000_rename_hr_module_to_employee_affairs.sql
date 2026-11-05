-- Rename the HR navigation module while preserving existing user and template permissions.
begin;

update public.erp_permission_template_rules
set menu_name = 'شئون موظفين'
where menu_name = 'موارد بشرية';

update public.erp_user_permission_matrix
set menu_name = 'شئون موظفين'
where menu_name = 'موارد بشرية';

commit;
