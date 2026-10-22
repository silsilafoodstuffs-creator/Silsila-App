-- Silsila: canonical item categories replacing the legacy "item groups" terminology.
-- Non-destructive migration: preserves UUIDs and existing item relationships.
create table if not exists public.erp_item_categories (
 id uuid primary key default gen_random_uuid(),
 company_id uuid not null references public.erp_companies(id) on delete restrict,
 parent_id uuid references public.erp_item_categories(id) on delete restrict,
 category_code text not null,
 category_name text not null,
 category_name_en text,
 is_active boolean not null default true,
 created_at timestamptz not null default now(),
 updated_at timestamptz not null default now(),
 unique(company_id, category_code)
);
alter table public.erp_items add column if not exists category_id uuid references public.erp_item_categories(id) on delete set null;
create index if not exists erp_item_categories_company_idx on public.erp_item_categories(company_id);
create index if not exists erp_items_category_idx on public.erp_items(category_id);
-- Keep IDs stable so item foreign keys can be migrated without losing references.
insert into public.erp_item_categories(id, company_id, parent_id, category_code, category_name, is_active)
select g.id, g.company_id, g.parent_id, g.group_code, g.group_name, g.is_active
from public.erp_item_groups g
on conflict (id) do nothing;
update public.erp_items i set category_id = i.group_id
where i.category_id is null and i.group_id is not null
and exists (select 1 from public.erp_item_categories c where c.id=i.group_id);
alter table public.erp_item_categories enable row level security;
drop policy if exists erp_item_categories_member_access on public.erp_item_categories;
create policy erp_item_categories_member_access on public.erp_item_categories for all to authenticated
using (public.erp_user_can_access_company(company_id))
with check (public.erp_user_can_access_company(company_id));
