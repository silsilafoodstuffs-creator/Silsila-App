create table if not exists public.erp_item_unit_catalog (
 id uuid primary key default gen_random_uuid(),
 company_id uuid not null references public.erp_companies(id) on delete cascade,
 activity_code text not null,
 unit_code text not null,
 unit_name_ar text not null,
 unit_name_en text,
 is_active boolean not null default true,
 created_at timestamptz not null default now(),
 updated_at timestamptz not null default now(),
 unique(company_id, activity_code, unit_code)
);
create index if not exists idx_erp_item_unit_catalog_activity on public.erp_item_unit_catalog(company_id, activity_code, unit_code);
alter table public.erp_item_unit_catalog enable row level security;
drop policy if exists erp_item_unit_catalog_member_access on public.erp_item_unit_catalog;
create policy erp_item_unit_catalog_member_access on public.erp_item_unit_catalog for all to authenticated
using (public.erp_user_can_access_company(company_id))
with check (public.erp_user_can_access_company(company_id));
