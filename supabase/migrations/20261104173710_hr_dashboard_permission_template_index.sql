create index if not exists idx_company_member_profiles_permission_template
  on public.erp_company_member_profiles(permission_template_id)
  where permission_template_id is not null;
