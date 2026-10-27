update public.erp_user_types
set is_active=false, show_at_login=false, description='حسابات الموظفين الداخلية'
where name_ar='موظف' and is_active=true;