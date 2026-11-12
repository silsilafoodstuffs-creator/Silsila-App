alter table public.offer_items
  add column if not exists min_quantity numeric(14,3) not null default 1;
alter table public.offer_items
  drop constraint if exists offer_items_min_quantity_positive;
alter table public.offer_items
  add constraint offer_items_min_quantity_positive check (min_quantity > 0);

alter table public.supplier_details
  add column if not exists allowed_customer_types jsonb not null default '[]'::jsonb;
alter table public.supplier_details
  drop constraint if exists supplier_details_allowed_customer_types_array;
alter table public.supplier_details
  add constraint supplier_details_allowed_customer_types_array
  check (jsonb_typeof(allowed_customer_types) = 'array');

create table if not exists public.erp_activity_customer_categories (
  id uuid primary key default gen_random_uuid(),
  company_id uuid not null,
  workspace_id uuid not null references public.erp_business_workspaces(id) on delete cascade,
  activity_type text not null,
  activity_name text not null,
  customer_category text not null,
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint erp_activity_customer_categories_unique unique (company_id, workspace_id, customer_category),
  constraint erp_activity_customer_categories_nonempty
    check (length(btrim(activity_type)) > 0 and length(btrim(activity_name)) > 0 and length(btrim(customer_category)) > 0)
);
create index if not exists erp_activity_customer_categories_company_workspace_idx
  on public.erp_activity_customer_categories(company_id, workspace_id, is_active);
alter table public.erp_activity_customer_categories enable row level security;

drop policy if exists erp_activity_customer_categories_select on public.erp_activity_customer_categories;
create policy erp_activity_customer_categories_select on public.erp_activity_customer_categories
  for select to authenticated using (public.erp_user_can_access_company(company_id));
drop policy if exists erp_activity_customer_categories_insert on public.erp_activity_customer_categories;
create policy erp_activity_customer_categories_insert on public.erp_activity_customer_categories
  for insert to authenticated with check (public.erp_user_has_company_role(company_id, array['owner','admin','manager']::text[]));
drop policy if exists erp_activity_customer_categories_update on public.erp_activity_customer_categories;
create policy erp_activity_customer_categories_update on public.erp_activity_customer_categories
  for update to authenticated using (public.erp_user_has_company_role(company_id, array['owner','admin','manager']::text[]))
  with check (public.erp_user_has_company_role(company_id, array['owner','admin','manager']::text[]));
drop policy if exists erp_activity_customer_categories_delete on public.erp_activity_customer_categories;
create policy erp_activity_customer_categories_delete on public.erp_activity_customer_categories
  for delete to authenticated using (public.erp_user_has_company_role(company_id, array['owner','admin']::text[]));
grant select, insert, update, delete on public.erp_activity_customer_categories to authenticated;

alter table public.offers add column if not exists target_geo_ids jsonb not null default '[]'::jsonb;
alter table public.offers drop constraint if exists offers_target_geo_ids_array;
alter table public.offers add constraint offers_target_geo_ids_array check (jsonb_typeof(target_geo_ids) = 'array');

create table if not exists public.supplier_offer_customer_categories (
  id uuid primary key default gen_random_uuid(),
  supplier_id uuid not null references public.profiles(id) on delete cascade,
  activity_type text not null,
  customer_category text not null,
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint supplier_offer_customer_categories_unique unique (supplier_id, activity_type, customer_category)
);
alter table public.supplier_offer_customer_categories enable row level security;
drop policy if exists supplier_offer_customer_categories_own on public.supplier_offer_customer_categories;
create policy supplier_offer_customer_categories_own on public.supplier_offer_customer_categories
  for all to authenticated using (supplier_id = auth.uid()) with check (supplier_id = auth.uid());
grant select, insert, update, delete on public.supplier_offer_customer_categories to authenticated;

create or replace function public.get_activity_customer_categories(p_activity_type text)
returns table(customer_category text, activity_name text)
language sql stable security definer set search_path = public
as $$
  select distinct c.customer_category, c.activity_name
  from public.erp_activity_customer_categories c
  where c.is_active = true and c.activity_type = p_activity_type
  order by c.activity_name, c.customer_category;
$$;
revoke all on function public.get_activity_customer_categories(text) from public;
grant execute on function public.get_activity_customer_categories(text) to authenticated;

create or replace function public.get_offer_geo_tree()
returns table(id uuid, parent_id uuid, name_ar text, level text, admin_type text)
language sql stable security definer set search_path = public
as $$
  with chosen_company as (
    select company_id from public.erp_geographic_data
    where is_active = true group by company_id order by count(*) desc limit 1
  )
  select g.id, g.parent_id, g.name_ar, g.level, g.admin_type
  from public.erp_geographic_data g
  join chosen_company c on c.company_id = g.company_id
  where g.is_active = true
  order by case g.level when 'governorate' then 1 when 'district' then 2 else 3 end, g.name_ar;
$$;
revoke all on function public.get_offer_geo_tree() from public;
grant execute on function public.get_offer_geo_tree() to authenticated;

create or replace function public.get_offer_geo_customer_counts()
returns table(governorate text, district text, area text, customer_count bigint)
language sql stable security definer set search_path = public
as $$
  select nullif(btrim(p.governorate), '') as governorate,
         nullif(btrim(p.district), '') as district,
         nullif(btrim(p.area), '') as area,
         count(*)::bigint as customer_count
  from public.profiles p
  where auth.uid() is not null
    and (lower(coalesce(p.account_type, '')) = 'customer' or lower(coalesce(p.role, '')) = 'customer')
    and p.account_status in ('approved','active','مفعل','معتمد')
    and nullif(btrim(p.governorate), '') is not null
  group by 1,2,3;
$$;
revoke all on function public.get_offer_geo_customer_counts() from public;
grant execute on function public.get_offer_geo_customer_counts() to authenticated;
