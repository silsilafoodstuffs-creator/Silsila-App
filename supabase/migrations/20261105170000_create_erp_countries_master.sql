-- Company-scoped country master used by the geographic data screen.
-- Egypt is seeded lazily by the screen when missing, using the Egyptian calling code 20.
create table if not exists public.erp_countries (
  id uuid primary key default gen_random_uuid(),
  company_id uuid not null references public.erp_companies(id) on delete cascade,
  country_code varchar(2) not null,
  name_ar text not null,
  name_en text,
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint erp_countries_code_format check (country_code ~ '^[0-9]{2}$'),
  constraint erp_countries_company_code_unique unique(company_id, country_code),
  constraint erp_countries_company_name_unique unique(company_id, name_ar)
);
create index if not exists idx_erp_countries_company_active
  on public.erp_countries(company_id, is_active, country_code);
alter table public.erp_countries enable row level security;
drop policy if exists erp_countries_member_access on public.erp_countries;
create policy erp_countries_member_access on public.erp_countries
  for all to authenticated
  using (public.erp_user_can_access_company(company_id))
  with check (public.erp_user_can_access_company(company_id));

-- Preserve the existing geographic tree and add Egypt as a separate country master row.
insert into public.erp_countries(company_id,country_code,name_ar,name_en,is_active)
select distinct company_id,'20','مصر','Egypt',true
from public.erp_geographic_data
on conflict(company_id,country_code) do nothing;
