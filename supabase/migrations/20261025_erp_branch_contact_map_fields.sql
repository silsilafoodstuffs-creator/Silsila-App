-- Branch contact and map point fields for the company branch directory.
-- Apply in Supabase SQL Editor after the ERP base schema.
begin;

alter table public.erp_branches
  add column if not exists email text,
  add column if not exists latitude double precision,
  add column if not exists longitude double precision;

alter table public.erp_branches
  drop constraint if exists erp_branches_latitude_range_check,
  add constraint erp_branches_latitude_range_check
    check (latitude is null or latitude between -90 and 90),
  drop constraint if exists erp_branches_longitude_range_check,
  add constraint erp_branches_longitude_range_check
    check (longitude is null or longitude between -180 and 180),
  drop constraint if exists erp_branches_coordinates_pair_check,
  add constraint erp_branches_coordinates_pair_check
    check ((latitude is null) = (longitude is null));

create index if not exists idx_erp_branches_company_main
  on public.erp_branches(company_id, is_main)
  where is_main;

commit;
