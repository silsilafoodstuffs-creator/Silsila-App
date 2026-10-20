-- ERP sales invoice sources: customer magazines, promotions, slow-moving offers and customer shortages.
-- Applied to Supabase project teitsopmhruczplwlwgn; keep this file for repeatable deployments.

create table if not exists public.erp_sales_campaigns (
  id uuid primary key default gen_random_uuid(),
  company_id uuid not null references public.erp_companies(id) on delete cascade,
  campaign_type text not null check (campaign_type in ('customer_magazine','promotion','slow_moving')),
  title text not null,
  start_date date not null,
  end_date date not null,
  owner_party_id uuid references public.erp_parties(id) on delete set null,
  owner_label text,
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  check (end_date >= start_date)
);
create index if not exists erp_sales_campaigns_lookup_idx
  on public.erp_sales_campaigns(company_id, campaign_type, is_active, start_date, end_date);

create table if not exists public.erp_sales_campaign_items (
  id uuid primary key default gen_random_uuid(),
  company_id uuid not null references public.erp_companies(id) on delete cascade,
  campaign_id uuid not null references public.erp_sales_campaigns(id) on delete cascade,
  item_id uuid not null references public.erp_items(id) on delete cascade,
  offer_price numeric(18,4) not null default 0 check (offer_price >= 0),
  min_quantity numeric(18,4) not null default 1 check (min_quantity > 0),
  max_quantity numeric(18,4) check (max_quantity is null or max_quantity >= min_quantity),
  representative_incentive numeric(18,4) not null default 0 check (representative_incentive >= 0),
  customer_incentive numeric(18,4) not null default 0 check (customer_incentive >= 0),
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  unique (campaign_id, item_id)
);
create index if not exists erp_sales_campaign_items_campaign_idx
  on public.erp_sales_campaign_items(company_id, campaign_id, is_active);

create table if not exists public.erp_customer_shortages (
  id uuid primary key default gen_random_uuid(),
  company_id uuid not null references public.erp_companies(id) on delete cascade,
  customer_id uuid not null references public.erp_parties(id) on delete cascade,
  item_id uuid not null references public.erp_items(id) on delete cascade,
  source_document_id uuid references public.erp_sales_documents(id) on delete set null,
  source_document_number text,
  source_date date not null default current_date,
  requested_quantity numeric(18,4) not null default 1 check (requested_quantity > 0),
  fulfilled_quantity numeric(18,4) not null default 0 check (fulfilled_quantity >= 0),
  status text not null default 'open' check (status in ('open','partial','closed','cancelled')),
  created_at timestamptz not null default now(),
  closed_at timestamptz,
  check (fulfilled_quantity <= requested_quantity)
);
create index if not exists erp_customer_shortages_open_idx
  on public.erp_customer_shortages(company_id, customer_id, status, source_date desc, created_at desc);

alter table public.erp_sales_campaigns enable row level security;
alter table public.erp_sales_campaign_items enable row level security;
alter table public.erp_customer_shortages enable row level security;

drop policy if exists erp_sales_campaigns_select_member on public.erp_sales_campaigns;
create policy erp_sales_campaigns_select_member on public.erp_sales_campaigns
for select to authenticated using (public.erp_user_can_access_company(company_id));
drop policy if exists erp_sales_campaigns_insert_operator on public.erp_sales_campaigns;
create policy erp_sales_campaigns_insert_operator on public.erp_sales_campaigns
for insert to authenticated with check (public.erp_user_has_company_role(company_id, array['owner','admin','manager','operator','accountant']));
drop policy if exists erp_sales_campaigns_update_operator on public.erp_sales_campaigns;
create policy erp_sales_campaigns_update_operator on public.erp_sales_campaigns
for update to authenticated using (public.erp_user_has_company_role(company_id, array['owner','admin','manager','operator','accountant']))
with check (public.erp_user_has_company_role(company_id, array['owner','admin','manager','operator','accountant']));
drop policy if exists erp_sales_campaigns_delete_admin on public.erp_sales_campaigns;
create policy erp_sales_campaigns_delete_admin on public.erp_sales_campaigns
for delete to authenticated using (public.erp_user_has_company_role(company_id, array['owner','admin']));

drop policy if exists erp_sales_campaign_items_select_member on public.erp_sales_campaign_items;
create policy erp_sales_campaign_items_select_member on public.erp_sales_campaign_items
for select to authenticated using (public.erp_user_can_access_company(company_id));
drop policy if exists erp_sales_campaign_items_insert_operator on public.erp_sales_campaign_items;
create policy erp_sales_campaign_items_insert_operator on public.erp_sales_campaign_items
for insert to authenticated with check (public.erp_user_has_company_role(company_id, array['owner','admin','manager','operator','accountant']));
drop policy if exists erp_sales_campaign_items_update_operator on public.erp_sales_campaign_items;
create policy erp_sales_campaign_items_update_operator on public.erp_sales_campaign_items
for update to authenticated using (public.erp_user_has_company_role(company_id, array['owner','admin','manager','operator','accountant']))
with check (public.erp_user_has_company_role(company_id, array['owner','admin','manager','operator','accountant']));
drop policy if exists erp_sales_campaign_items_delete_admin on public.erp_sales_campaign_items;
create policy erp_sales_campaign_items_delete_admin on public.erp_sales_campaign_items
for delete to authenticated using (public.erp_user_has_company_role(company_id, array['owner','admin']));

drop policy if exists erp_customer_shortages_select_member on public.erp_customer_shortages;
create policy erp_customer_shortages_select_member on public.erp_customer_shortages
for select to authenticated using (public.erp_user_can_access_company(company_id));
drop policy if exists erp_customer_shortages_insert_operator on public.erp_customer_shortages;
create policy erp_customer_shortages_insert_operator on public.erp_customer_shortages
for insert to authenticated with check (public.erp_user_has_company_role(company_id, array['owner','admin','manager','operator','accountant']));
drop policy if exists erp_customer_shortages_update_operator on public.erp_customer_shortages;
create policy erp_customer_shortages_update_operator on public.erp_customer_shortages
for update to authenticated using (public.erp_user_has_company_role(company_id, array['owner','admin','manager','operator','accountant']))
with check (public.erp_user_has_company_role(company_id, array['owner','admin','manager','operator','accountant']));
drop policy if exists erp_customer_shortages_delete_operator on public.erp_customer_shortages;
create policy erp_customer_shortages_delete_operator on public.erp_customer_shortages
for delete to authenticated using (public.erp_user_has_company_role(company_id, array['owner','admin','manager','operator','accountant']));

grant select, insert, update, delete on public.erp_sales_campaigns to authenticated;
grant select, insert, update, delete on public.erp_sales_campaign_items to authenticated;
grant select, insert, update, delete on public.erp_customer_shortages to authenticated;
