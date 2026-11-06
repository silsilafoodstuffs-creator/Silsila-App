alter table public.erp_asset_movements add column if not exists suite_record_code text;
alter table public.erp_construction_boq_lines add column if not exists suite_record_code text;
alter table public.erp_construction_costs add column if not exists suite_record_code text;
create unique index if not exists erp_asset_movements_company_suite_code_uidx on public.erp_asset_movements(company_id,suite_record_code) where suite_record_code is not null;
create unique index if not exists erp_construction_boq_company_suite_code_uidx on public.erp_construction_boq_lines(company_id,suite_record_code) where suite_record_code is not null;
create unique index if not exists erp_construction_costs_company_suite_code_uidx on public.erp_construction_costs(company_id,suite_record_code) where suite_record_code is not null;