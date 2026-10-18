-- Apply after supabase/erp_schema.sql and supabase/erp_security_membership.sql.
-- These fields preserve provenance for imported public-directory leads.
alter table public.erp_parties
  add column if not exists business_classification text,
  add column if not exists source_name text,
  add column if not exists source_url text,
  add column if not exists is_demo_data boolean not null default false;

create index if not exists erp_parties_classification_idx
  on public.erp_parties(company_id, business_classification);

-- Optional merchandising fields used by the demo catalog and future supplier imports.
alter table public.erp_items
  add column if not exists brand_name text,
  add column if not exists package_description text,
  add column if not exists image_url text,
  add column if not exists source_name text,
  add column if not exists is_demo_data boolean not null default false;

create index if not exists erp_items_brand_idx
  on public.erp_items(company_id, brand_name);
