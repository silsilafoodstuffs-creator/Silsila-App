-- The table already has the equivalent company-scoped unique constraint.
-- Remove the extra index created by the preceding compatibility migration.
drop index if exists public.erp_crm_activities_company_activity_code_uidx;
