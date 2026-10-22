alter table public.erp_branches
 add column if not exists branch_name_en text,
 add column if not exists governorate_id uuid references public.erp_geographic_data(id) on delete set null,
 add column if not exists district_id uuid references public.erp_geographic_data(id) on delete set null,
 add column if not exists area_id uuid references public.erp_geographic_data(id) on delete set null,
 add column if not exists location text,
 add column if not exists phone2 text,
 add column if not exists landline1 text,
 add column if not exists landline2 text;
create index if not exists idx_erp_branches_geo on public.erp_branches(company_id, governorate_id, district_id, area_id);