create table if not exists public.erp_geographic_data (
 id uuid primary key default gen_random_uuid(),
 company_id uuid not null references public.erp_companies(id) on delete cascade,
 parent_id uuid null references public.erp_geographic_data(id) on delete restrict,
 geo_code text not null, name_ar text not null, name_en text null,
 level text not null check (level in ('governorate','district','area')),
 is_active boolean not null default true,
 logo_url text null, logo_source_url text null,
 logo_bytes bytea null, logo_mime_type text null, logo_sha256 text null,
 logo_bytes_updated_at timestamptz null,
 source_name text null, source_url text null,
 name_source_name text null, name_source_url text null,
 latitude double precision null, longitude double precision null,
 created_at timestamptz not null default now(),
 updated_at timestamptz not null default now(),
 constraint erp_geographic_data_code_per_company unique(company_id,geo_code)
);
create index if not exists idx_erp_geographic_data_company_parent on public.erp_geographic_data(company_id,parent_id,level);
alter table public.erp_geographic_data enable row level security;
drop policy if exists erp_geographic_data_member_access on public.erp_geographic_data;
create policy erp_geographic_data_member_access on public.erp_geographic_data for all to authenticated using (public.erp_user_can_access_company(company_id)) with check (public.erp_user_can_access_company(company_id));

create index if not exists idx_erp_geographic_data_company_level on public.erp_geographic_data(company_id,level,geo_code);

-- Existing installations: preserve the original URL metadata while storing image bytes in PostgreSQL.
alter table public.erp_geographic_data add column if not exists logo_bytes bytea null;
alter table public.erp_geographic_data add column if not exists logo_mime_type text null;
alter table public.erp_geographic_data add column if not exists logo_sha256 text null;
alter table public.erp_geographic_data add column if not exists logo_bytes_updated_at timestamptz null;

alter table public.erp_geographic_data add column if not exists name_source_name text null;
alter table public.erp_geographic_data add column if not exists name_source_url text null;
