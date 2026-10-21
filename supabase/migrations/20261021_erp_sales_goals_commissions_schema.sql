-- Silsila ERP: sales targets, commission rules, geographic directory and clearly-labelled demo data.
-- Prerequisites: apply erp_schema.sql and erp_operations_schema.sql first.
-- This migration creates structures only; it does NOT import private competitor data,
-- scrape Google Maps/social networks, or pretend demo records are verified businesses.
-- Run from Supabase SQL Editor. RLS is enabled without broad client policies by design.

create table if not exists public.erp_geo_areas (
  id uuid primary key default gen_random_uuid(),
  parent_id uuid references public.erp_geo_areas(id) on delete restrict,
  governorate text not null,
  area_name text not null,
  area_kind text not null check (area_kind in ('governorate','city','district','center','village','neighborhood','industrial_zone','market','other')),
  name_ar text not null,
  name_en text,
  postal_code text,
  latitude numeric(10,7),
  longitude numeric(10,7),
  source_name text not null default 'seed_reference',
  source_url text,
  is_verified boolean not null default false,
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  unique(parent_id, area_kind, name_ar)
);

create index if not exists erp_geo_areas_parent_idx on public.erp_geo_areas(parent_id);
create index if not exists erp_geo_areas_governorate_idx on public.erp_geo_areas(governorate, area_kind);

create table if not exists public.erp_sales_representatives (
  id uuid primary key default gen_random_uuid(),
  company_id uuid not null references public.erp_companies(id) on delete cascade,
  rep_code text not null,
  rep_name text not null,
  phone text,
  email text,
  home_area_id uuid references public.erp_geo_areas(id) on delete set null,
  assigned_area_ids uuid[] not null default '{}',
  monthly_sales_target numeric(14,2) not null default 0 check (monthly_sales_target >= 0),
  monthly_collection_target numeric(14,2) not null default 0 check (monthly_collection_target >= 0),
  commission_plan text not null default 'percentage' check (commission_plan in ('percentage','fixed_per_invoice','tiered')),
  default_commission_rate numeric(7,4) not null default 0 check (default_commission_rate >= 0),
  is_demo_data boolean not null default false,
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique(company_id, rep_code)
);

create table if not exists public.erp_customer_monthly_goals (
  id uuid primary key default gen_random_uuid(),
  company_id uuid not null references public.erp_companies(id) on delete cascade,
  customer_id uuid not null references public.erp_parties(id) on delete cascade,
  goal_month date not null,
  sales_target numeric(14,2) not null default 0 check (sales_target >= 0),
  collection_target numeric(14,2) not null default 0 check (collection_target >= 0),
  target_orders integer not null default 0 check (target_orders >= 0),
  bonus_rate numeric(7,4) not null default 0 check (bonus_rate >= 0),
  notes text,
  is_demo_data boolean not null default false,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique(company_id, customer_id, goal_month)
);

create table if not exists public.erp_commission_plans (
  id uuid primary key default gen_random_uuid(),
  company_id uuid not null references public.erp_companies(id) on delete cascade,
  plan_code text not null,
  plan_name text not null,
  calculation_basis text not null check (calculation_basis in ('sales_value','collected_value','gross_profit','invoice_count')),
  commission_method text not null check (commission_method in ('percentage','fixed_per_invoice','tiered')),
  flat_rate numeric(7,4) not null default 0 check (flat_rate >= 0),
  fixed_amount numeric(14,2) not null default 0 check (fixed_amount >= 0),
  min_target_percent numeric(7,2) not null default 0 check (min_target_percent >= 0),
  max_commission numeric(14,2),
  effective_from date not null default current_date,
  effective_to date,
  is_demo_data boolean not null default false,
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique(company_id, plan_code),
  check (effective_to is null or effective_to >= effective_from)
);

create table if not exists public.erp_commission_tiers (
  id uuid primary key default gen_random_uuid(),
  plan_id uuid not null references public.erp_commission_plans(id) on delete cascade,
  min_value numeric(14,2) not null default 0 check (min_value >= 0),
  max_value numeric(14,2),
  rate numeric(7,4) not null default 0 check (rate >= 0),
  fixed_amount numeric(14,2) not null default 0 check (fixed_amount >= 0),
  created_at timestamptz not null default now(),
  check (max_value is null or max_value >= min_value),
  unique(plan_id, min_value)
);

create table if not exists public.erp_commission_runs (
  id uuid primary key default gen_random_uuid(),
  company_id uuid not null references public.erp_companies(id) on delete cascade,
  representative_id uuid not null references public.erp_sales_representatives(id) on delete restrict,
  plan_id uuid references public.erp_commission_plans(id) on delete restrict,
  period_start date not null,
  period_end date not null,
  eligible_sales numeric(14,2) not null default 0,
  eligible_collections numeric(14,2) not null default 0,
  eligible_gross_profit numeric(14,2) not null default 0,
  eligible_invoice_count integer not null default 0,
  calculated_commission numeric(14,2) not null default 0,
  status text not null default 'draft' check (status in ('draft','reviewed','approved','paid','cancelled')),
  is_demo_data boolean not null default false,
  notes text,
  created_at timestamptz not null default now(),
  check (period_end >= period_start)
);

alter table public.erp_parties
  add column if not exists business_classification text,
  add column if not exists sales_rep_id uuid references public.erp_sales_representatives(id) on delete set null,
  add column if not exists geo_area_id uuid references public.erp_geo_areas(id) on delete set null,
  add column if not exists latitude numeric(10,7),
  add column if not exists longitude numeric(10,7),
  add column if not exists source_name text,
  add column if not exists source_url text,
  add column if not exists is_demo_data boolean not null default false;

alter table public.erp_items
  add column if not exists brand_name text,
  add column if not exists package_description text,
  add column if not exists image_url text,
  add column if not exists source_name text,
  add column if not exists source_url text,
  add column if not exists is_demo_data boolean not null default false;

alter table public.erp_sales_documents
  add column if not exists sales_rep_id uuid references public.erp_sales_representatives(id) on delete set null,
  add column if not exists is_demo_data boolean not null default false;

alter table public.erp_purchase_documents
  add column if not exists is_demo_data boolean not null default false;


alter table public.erp_sales_representatives
  add column if not exists email text,
  add column if not exists home_area_id uuid references public.erp_geo_areas(id) on delete set null,
  add column if not exists assigned_area_ids uuid[] not null default '{}',
  add column if not exists monthly_sales_target numeric(14,2) not null default 0 check (monthly_sales_target >= 0),
  add column if not exists monthly_collection_target numeric(14,2) not null default 0 check (monthly_collection_target >= 0),
  add column if not exists commission_plan text not null default 'percentage' check (commission_plan in ('percentage','fixed_per_invoice','tiered')),
  add column if not exists default_commission_rate numeric(7,4) not null default 0 check (default_commission_rate >= 0),
  add column if not exists is_demo_data boolean not null default false;

alter table public.erp_parties
  add column if not exists business_classification text,
  add column if not exists geo_area_id uuid references public.erp_geo_areas(id) on delete set null,
  add column if not exists latitude numeric(10,7),
  add column if not exists longitude numeric(10,7),
  add column if not exists source_name text,
  add column if not exists source_url text,
  add column if not exists is_demo_data boolean not null default false;
alter table public.erp_items
  add column if not exists brand_name text,
  add column if not exists package_description text,
  add column if not exists source_name text,
  add column if not exists source_url text,
  add column if not exists is_demo_data boolean not null default false;
alter table public.erp_sales_documents add column if not exists is_demo_data boolean not null default false;
alter table public.erp_purchase_documents add column if not exists is_demo_data boolean not null default false;

alter table public.erp_geo_areas enable row level security;
alter table public.erp_customer_monthly_goals enable row level security;
alter table public.erp_commission_plans enable row level security;
alter table public.erp_commission_tiers enable row level security;
alter table public.erp_commission_runs enable row level security;

drop policy if exists erp_geo_areas_read_authenticated on public.erp_geo_areas;
create policy erp_geo_areas_read_authenticated on public.erp_geo_areas for select to authenticated using (true);
drop policy if exists erp_customer_goals_select_company on public.erp_customer_monthly_goals;
create policy erp_customer_goals_select_company on public.erp_customer_monthly_goals for select to authenticated
using (public.erp_user_can_access_company(company_id));
drop policy if exists erp_customer_goals_write_sales on public.erp_customer_monthly_goals;
create policy erp_customer_goals_write_sales on public.erp_customer_monthly_goals for all to authenticated
using (public.erp_user_has_company_role(company_id,array['owner','admin','manager','accountant']::text[]))
with check (public.erp_user_has_company_role(company_id,array['owner','admin','manager','accountant']::text[]));
drop policy if exists erp_commission_plans_select_company on public.erp_commission_plans;
create policy erp_commission_plans_select_company on public.erp_commission_plans for select to authenticated
using (public.erp_user_can_access_company(company_id));
drop policy if exists erp_commission_plans_write_manager on public.erp_commission_plans;
create policy erp_commission_plans_write_manager on public.erp_commission_plans for all to authenticated
using (public.erp_user_has_company_role(company_id,array['owner','admin','manager','accountant']::text[]))
with check (public.erp_user_has_company_role(company_id,array['owner','admin','manager','accountant']::text[]));
drop policy if exists erp_commission_tiers_select_company on public.erp_commission_tiers;
create policy erp_commission_tiers_select_company on public.erp_commission_tiers for select to authenticated
using (exists (select 1 from public.erp_commission_plans p where p.id=plan_id and public.erp_user_can_access_company(p.company_id)));
drop policy if exists erp_commission_tiers_write_manager on public.erp_commission_tiers;
create policy erp_commission_tiers_write_manager on public.erp_commission_tiers for all to authenticated
using (exists (select 1 from public.erp_commission_plans p where p.id=plan_id and public.erp_user_has_company_role(p.company_id,array['owner','admin','manager','accountant']::text[])))
with check (exists (select 1 from public.erp_commission_plans p where p.id=plan_id and public.erp_user_has_company_role(p.company_id,array['owner','admin','manager','accountant']::text[])));
drop policy if exists erp_commission_runs_select_company on public.erp_commission_runs;
create policy erp_commission_runs_select_company on public.erp_commission_runs for select to authenticated
using (public.erp_user_can_access_company(company_id));
drop policy if exists erp_commission_runs_write_manager on public.erp_commission_runs;
create policy erp_commission_runs_write_manager on public.erp_commission_runs for all to authenticated
using (public.erp_user_has_company_role(company_id,array['owner','admin','manager','accountant']::text[]))
with check (public.erp_user_has_company_role(company_id,array['owner','admin','manager','accountant']::text[]));

grant select on public.erp_geo_areas to authenticated;
grant select,insert,update,delete on public.erp_customer_monthly_goals, public.erp_commission_plans,
  public.erp_commission_tiers, public.erp_commission_runs, public.erp_sales_representatives to authenticated;

create or replace function public.erp_validate_sales_target_links()
returns trigger language plpgsql security definer set search_path = public set row_security = off as $$
declare v_company_id uuid;
begin
  if tg_table_name = 'erp_customer_monthly_goals' then
    select company_id into v_company_id from public.erp_parties where id=new.customer_id;
    if v_company_id is distinct from new.company_id then raise exception 'العميل يجب أن يتبع الشركة نفسها المحددة في الهدف الشهري'; end if;
  elsif tg_table_name = 'erp_commission_runs' then
    select company_id into v_company_id from public.erp_sales_representatives where id=new.representative_id;
    if v_company_id is distinct from new.company_id then raise exception 'مندوب المبيعات يجب أن يتبع الشركة نفسها المحددة في مسير العمولة'; end if;
    if new.plan_id is not null then
      select company_id into v_company_id from public.erp_commission_plans where id=new.plan_id;
      if v_company_id is distinct from new.company_id then raise exception 'خطة العمولة يجب أن تتبع الشركة نفسها'; end if;
    end if;
  end if;
  return new;
end;
$$;
revoke all on function public.erp_validate_sales_target_links() from public, anon, authenticated;
drop trigger if exists erp_customer_goal_company_guard on public.erp_customer_monthly_goals;
create trigger erp_customer_goal_company_guard before insert or update of company_id,customer_id
on public.erp_customer_monthly_goals for each row execute function public.erp_validate_sales_target_links();
drop trigger if exists erp_commission_run_company_guard on public.erp_commission_runs;
create trigger erp_commission_run_company_guard before insert or update of company_id,representative_id,plan_id
on public.erp_commission_runs for each row execute function public.erp_validate_sales_target_links();

insert into public.erp_geo_areas(parent_id,governorate,area_name,area_kind,name_ar,name_en,source_name,source_url,is_verified)
select null,x.gov,x.gov,'governorate','محافظة ' || x.gov,x.name_en,'CAPMAS / public reference','https://www.capmas.gov.eg/',false
from (values
('القاهرة','Cairo'),('الجيزة','Giza'),('القليوبية','Qalyubia'),('الإسكندرية','Alexandria'),
('البحيرة','Beheira'),('مطروح','Matrouh'),('كفر الشيخ','Kafr El Sheikh'),('الغربية','Gharbia'),
('المنوفية','Menoufia'),('الدقهلية','Dakahlia'),('دمياط','Damietta'),('بورسعيد','Port Said'),
('الإسماعيلية','Ismailia'),('السويس','Suez'),('شمال سيناء','North Sinai'),('جنوب سيناء','South Sinai'),
('الشرقية','Sharqia'),('الفيوم','Fayoum'),('بني سويف','Beni Suef'),('المنيا','Minya'),
('أسيوط','Assiut'),('سوهاج','Sohag'),('قنا','Qena'),('الأقصر','Luxor'),
('أسوان','Aswan'),('البحر الأحمر','Red Sea'),('الوادي الجديد','New Valley')
) as x(gov,name_en)
where not exists (select 1 from public.erp_geo_areas g where g.parent_id is null and g.governorate=x.gov and g.area_kind='governorate');


-- Existing representative table may predate this schema, so ensure RLS and policies explicitly.
alter table public.erp_sales_representatives enable row level security;
drop policy if exists erp_sales_representatives_select_member on public.erp_sales_representatives;
drop policy if exists erp_sales_representatives_insert_operator on public.erp_sales_representatives;
drop policy if exists erp_sales_representatives_update_operator on public.erp_sales_representatives;
drop policy if exists erp_sales_representatives_delete_admin on public.erp_sales_representatives;
drop policy if exists erp_sales_reps_select_company on public.erp_sales_representatives;
drop policy if exists erp_sales_reps_write_manager on public.erp_sales_representatives;
create policy erp_sales_representatives_select_member on public.erp_sales_representatives
for select to authenticated using (public.erp_user_can_access_company(company_id));
create policy erp_sales_representatives_insert_manager on public.erp_sales_representatives
for insert to authenticated with check (public.erp_user_has_company_role(company_id,array['owner','admin','manager','accountant']::text[]));
create policy erp_sales_representatives_update_manager on public.erp_sales_representatives
for update to authenticated
using (public.erp_user_has_company_role(company_id,array['owner','admin','manager','accountant']::text[]))
with check (public.erp_user_has_company_role(company_id,array['owner','admin','manager','accountant']::text[]));
create policy erp_sales_representatives_delete_admin on public.erp_sales_representatives
for delete to authenticated using (public.erp_user_has_company_role(company_id,array['owner','admin']::text[]));

-- Separate read and write policies to avoid overlapping permissive SELECT rules.
drop policy if exists erp_customer_goals_write_sales on public.erp_customer_monthly_goals;
drop policy if exists erp_customer_goals_insert_sales on public.erp_customer_monthly_goals;
create policy erp_customer_goals_insert_sales on public.erp_customer_monthly_goals for insert to authenticated
with check (public.erp_user_has_company_role(company_id,array['owner','admin','manager','accountant']::text[]));
drop policy if exists erp_customer_goals_update_sales on public.erp_customer_monthly_goals;
create policy erp_customer_goals_update_sales on public.erp_customer_monthly_goals for update to authenticated
using (public.erp_user_has_company_role(company_id,array['owner','admin','manager','accountant']::text[]))
with check (public.erp_user_has_company_role(company_id,array['owner','admin','manager','accountant']::text[]));
drop policy if exists erp_customer_goals_delete_sales on public.erp_customer_monthly_goals;
create policy erp_customer_goals_delete_sales on public.erp_customer_monthly_goals for delete to authenticated
using (public.erp_user_has_company_role(company_id,array['owner','admin','accountant']::text[]));

drop policy if exists erp_commission_plans_write_manager on public.erp_commission_plans;
drop policy if exists erp_commission_plans_insert_manager on public.erp_commission_plans;
create policy erp_commission_plans_insert_manager on public.erp_commission_plans for insert to authenticated
with check (public.erp_user_has_company_role(company_id,array['owner','admin','manager','accountant']::text[]));
drop policy if exists erp_commission_plans_update_manager on public.erp_commission_plans;
create policy erp_commission_plans_update_manager on public.erp_commission_plans for update to authenticated
using (public.erp_user_has_company_role(company_id,array['owner','admin','manager','accountant']::text[]))
with check (public.erp_user_has_company_role(company_id,array['owner','admin','manager','accountant']::text[]));
drop policy if exists erp_commission_plans_delete_manager on public.erp_commission_plans;
create policy erp_commission_plans_delete_manager on public.erp_commission_plans for delete to authenticated
using (public.erp_user_has_company_role(company_id,array['owner','admin','accountant']::text[]));

drop policy if exists erp_commission_tiers_write_manager on public.erp_commission_tiers;
drop policy if exists erp_commission_tiers_insert_manager on public.erp_commission_tiers;
create policy erp_commission_tiers_insert_manager on public.erp_commission_tiers for insert to authenticated
with check (exists (select 1 from public.erp_commission_plans p where p.id=plan_id and public.erp_user_has_company_role(p.company_id,array['owner','admin','manager','accountant']::text[])));
drop policy if exists erp_commission_tiers_update_manager on public.erp_commission_tiers;
create policy erp_commission_tiers_update_manager on public.erp_commission_tiers for update to authenticated
using (exists (select 1 from public.erp_commission_plans p where p.id=plan_id and public.erp_user_has_company_role(p.company_id,array['owner','admin','manager','accountant']::text[])))
with check (exists (select 1 from public.erp_commission_plans p where p.id=plan_id and public.erp_user_has_company_role(p.company_id,array['owner','admin','manager','accountant']::text[])));
drop policy if exists erp_commission_tiers_delete_manager on public.erp_commission_tiers;
create policy erp_commission_tiers_delete_manager on public.erp_commission_tiers for delete to authenticated
using (exists (select 1 from public.erp_commission_plans p where p.id=plan_id and public.erp_user_has_company_role(p.company_id,array['owner','admin','accountant']::text[])));

drop policy if exists erp_commission_runs_write_manager on public.erp_commission_runs;
drop policy if exists erp_commission_runs_insert_manager on public.erp_commission_runs;
create policy erp_commission_runs_insert_manager on public.erp_commission_runs for insert to authenticated
with check (public.erp_user_has_company_role(company_id,array['owner','admin','accountant']::text[]));
drop policy if exists erp_commission_runs_update_manager on public.erp_commission_runs;
create policy erp_commission_runs_update_manager on public.erp_commission_runs for update to authenticated
using (public.erp_user_has_company_role(company_id,array['owner','admin','accountant']::text[]))
with check (public.erp_user_has_company_role(company_id,array['owner','admin','accountant']::text[]));
drop policy if exists erp_commission_runs_delete_manager on public.erp_commission_runs;
create policy erp_commission_runs_delete_manager on public.erp_commission_runs for delete to authenticated
using (status in ('draft','cancelled') and public.erp_user_has_company_role(company_id,array['owner','admin','accountant']::text[]));
