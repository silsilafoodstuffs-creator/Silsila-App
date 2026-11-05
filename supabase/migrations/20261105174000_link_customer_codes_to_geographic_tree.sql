-- Attach customer code generation to the geographic tree used by the ERP screen.
alter table public.erp_parties
  add column if not exists geographic_area_id uuid null
  references public.erp_geographic_data(id) on delete set null;
create index if not exists idx_erp_parties_geographic_area
  on public.erp_parties(company_id, geographic_area_id)
  where geographic_area_id is not null;
