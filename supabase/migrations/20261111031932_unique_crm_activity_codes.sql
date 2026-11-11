-- Prevent duplicate CRM activities within the same company.
-- Existing rows were checked for duplicate (company_id, activity_code) pairs before applying.
create unique index if not exists erp_crm_activities_company_activity_code_uidx
  on public.erp_crm_activities (company_id, activity_code);
