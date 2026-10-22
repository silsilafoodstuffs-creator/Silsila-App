-- Extend warehouses for the branch-linked bilingual/geographic directory.
alter table public.erp_warehouses
 add column if not exists warehouse_name_en text,
 add column if not exists parent_warehouse_id uuid references public.erp_warehouses(id) on delete restrict,
 add column if not exists governorate_id uuid references public.erp_geographic_data(id) on delete set null,
 add column if not exists district_id uuid references public.erp_geographic_data(id) on delete set null,
 add column if not exists area_id uuid references public.erp_geographic_data(id) on delete set null,
 add column if not exists location text,
 add column if not exists phone text,
 add column if not exists landline text;
create index if not exists erp_warehouses_parent_idx on public.erp_warehouses(company_id,parent_warehouse_id);
create index if not exists erp_warehouses_geo_idx on public.erp_warehouses(company_id,governorate_id,district_id,area_id);
