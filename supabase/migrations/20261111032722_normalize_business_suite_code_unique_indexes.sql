-- Convert code indexes used by Business Suite from partial to full unique indexes.
-- PostgreSQL UNIQUE indexes still allow multiple NULL values by default, so this
-- preserves the previous uniqueness semantics while enabling standard ON CONFLICT targets.
create unique index erp_asset_movements_company_suite_code_full_uidx
  on public.erp_asset_movements (company_id, suite_record_code);
drop index if exists public.erp_asset_movements_company_suite_code_uidx;

create unique index erp_production_quality_checks_company_code_full_uidx
  on public.erp_production_quality_checks (company_id, inspection_code);
drop index if exists public.erp_production_quality_checks_company_code_uidx;

create unique index erp_construction_boq_company_suite_code_full_uidx
  on public.erp_construction_boq_lines (company_id, suite_record_code);
drop index if exists public.erp_construction_boq_company_suite_code_uidx;

create unique index erp_construction_costs_company_suite_code_full_uidx
  on public.erp_construction_costs (company_id, suite_record_code);
drop index if exists public.erp_construction_costs_company_suite_code_uidx;
