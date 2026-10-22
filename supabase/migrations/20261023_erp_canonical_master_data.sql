-- Silsila canonical master data migration (applied to project teitsopmhruczplwlwgn on 2026-10-23).
-- Safe to re-run: legacy records and IDs are preserved.
create table if not exists public.erp_item_categories (
 id uuid primary key default gen_random_uuid(),
 company_id uuid not null references public.erp_companies(id) on delete restrict,
 parent_id uuid references public.erp_item_categories(id) on delete restrict,
 category_code text not null,
 category_name text not null,
 category_name_en text,
 activity_code text,
 show_in_app boolean not null default true,
 image_url text,
 image_data bytea,
 image_mime_type text,
 is_active boolean not null default true,
 created_at timestamptz not null default now(),
 updated_at timestamptz not null default now(),
 unique(company_id,category_code)
);
insert into public.erp_item_categories(id,company_id,parent_id,category_code,category_name,category_name_en,activity_code,show_in_app,image_url,image_data,image_mime_type,is_active)
select id,company_id,parent_id,group_code,group_name,group_name_en,activity_code,coalesce(show_in_app,true),image_url,image_data,image_mime_type,is_active
from public.erp_item_groups on conflict(id) do nothing;
alter table public.erp_items add column if not exists category_id uuid references public.erp_item_categories(id) on delete set null;
update public.erp_items set category_id=group_id where category_id is null and group_id is not null
and exists(select 1 from public.erp_item_categories c where c.id=erp_items.group_id);
create index if not exists erp_item_categories_company_idx on public.erp_item_categories(company_id);
create index if not exists erp_items_category_idx on public.erp_items(category_id);
alter table public.erp_item_categories enable row level security;
drop policy if exists erp_item_categories_member_access on public.erp_item_categories;
create policy erp_item_categories_member_access on public.erp_item_categories for all to authenticated
using(public.erp_user_can_access_company(company_id)) with check(public.erp_user_can_access_company(company_id));

create table if not exists public.erp_item_unit_catalog (
 id uuid primary key default gen_random_uuid(),
 company_id uuid not null references public.erp_companies(id) on delete cascade,
 activity_code text not null, unit_code text not null, unit_name_ar text not null,
 unit_name_en text, is_active boolean not null default true,
 created_at timestamptz not null default now(), updated_at timestamptz not null default now(),
 unique(company_id,activity_code,unit_code)
);
create index if not exists idx_erp_item_unit_catalog_activity on public.erp_item_unit_catalog(company_id,activity_code,unit_code);
alter table public.erp_item_unit_catalog enable row level security;
drop policy if exists erp_item_unit_catalog_member_access on public.erp_item_unit_catalog;
create policy erp_item_unit_catalog_member_access on public.erp_item_unit_catalog for all to authenticated
using(public.erp_user_can_access_company(company_id)) with check(public.erp_user_can_access_company(company_id));

create table if not exists public.erp_geographic_data (
 id uuid primary key default gen_random_uuid(),
 company_id uuid not null references public.erp_companies(id) on delete cascade,
 parent_id uuid references public.erp_geographic_data(id) on delete restrict,
 geo_code text not null, name_ar text not null, name_en text,
 level text not null check(level in ('governorate','district','area')),
 is_active boolean not null default true,
 created_at timestamptz not null default now(), updated_at timestamptz not null default now(),
 unique(company_id,geo_code)
);
create index if not exists idx_erp_geographic_data_company_parent on public.erp_geographic_data(company_id,parent_id,level);
alter table public.erp_geographic_data enable row level security;
drop policy if exists erp_geographic_data_member_access on public.erp_geographic_data;
create policy erp_geographic_data_member_access on public.erp_geographic_data for all to authenticated
using(public.erp_user_can_access_company(company_id)) with check(public.erp_user_can_access_company(company_id));

alter table public.erp_branches
 add column if not exists branch_name_en text,
 add column if not exists governorate_id uuid references public.erp_geographic_data(id) on delete set null,
 add column if not exists district_id uuid references public.erp_geographic_data(id) on delete set null,
 add column if not exists area_id uuid references public.erp_geographic_data(id) on delete set null,
 add column if not exists location text, add column if not exists phone2 text,
 add column if not exists landline1 text, add column if not exists landline2 text;
create index if not exists idx_erp_branches_geo on public.erp_branches(company_id,governorate_id,district_id,area_id);
alter table public.erp_warehouses
 add column if not exists warehouse_name_en text,
 add column if not exists parent_warehouse_id uuid references public.erp_warehouses(id) on delete restrict,
 add column if not exists governorate_id uuid references public.erp_geographic_data(id) on delete set null,
 add column if not exists district_id uuid references public.erp_geographic_data(id) on delete set null,
 add column if not exists area_id uuid references public.erp_geographic_data(id) on delete set null,
 add column if not exists location text, add column if not exists phone text, add column if not exists landline text;
create index if not exists erp_warehouses_parent_idx on public.erp_warehouses(company_id,parent_warehouse_id);
create index if not exists erp_warehouses_geo_idx on public.erp_warehouses(company_id,governorate_id,district_id,area_id);

create or replace function public.erp_validate_item_category_link()
returns trigger language plpgsql set search_path=public as $$
declare parent_company uuid; parent_activity text; cycle_found boolean;
begin
 if new.parent_id is not null then
  select company_id,activity_code into parent_company,parent_activity from public.erp_item_categories where id=new.parent_id;
  if parent_company is distinct from new.company_id then raise exception 'الفئة الرئيسية يجب أن تتبع الشركة نفسها'; end if;
  if parent_activity is distinct from new.activity_code then raise exception 'الفئة الرئيسية يجب أن تتبع النشاط نفسه'; end if;
  with recursive descendants(id,path) as (
   select new.id,array[new.id]::uuid[] union all
   select c.id,d.path||c.id from descendants d join public.erp_item_categories c on c.parent_id=d.id where not c.id=any(d.path)
  ) select exists(select 1 from descendants where id=new.parent_id) into cycle_found;
  if coalesce(cycle_found,false) then raise exception 'لا يمكن وضع الفئة تحت أحد أحفادها'; end if;
 end if;
 if nullif(btrim(coalesce(new.category_name,'')),'') is not null and exists(
  select 1 from public.erp_item_categories c where c.company_id=new.company_id
  and c.activity_code is not distinct from new.activity_code
  and lower(btrim(c.category_name))=lower(btrim(new.category_name)) and c.id is distinct from new.id
 ) then raise exception 'اسم الفئة مستخدم بالفعل داخل هذا النشاط: %',new.category_name using errcode='23505'; end if;
 return new;
end $$;
drop trigger if exists erp_item_categories_parent_guard on public.erp_item_categories;
create trigger erp_item_categories_parent_guard before insert or update of company_id,parent_id,activity_code,category_name
on public.erp_item_categories for each row execute function public.erp_validate_item_category_link();

create or replace function public.erp_validate_item_category_assignment()
returns trigger language plpgsql set search_path=public as $$
declare category_company uuid; category_active boolean;
begin
 if new.category_id is not null then
  select company_id,is_active into category_company,category_active from public.erp_item_categories where id=new.category_id;
  if category_company is distinct from new.company_id or category_active is distinct from true then
   raise exception 'فئة الصنف غير نشطة أو لا تتبع الشركة نفسها';
  end if;
 end if;
 return new;
end $$;
drop trigger if exists erp_item_categories_item_guard on public.erp_items;
create trigger erp_item_categories_item_guard before insert or update of company_id,category_id
on public.erp_items for each row execute function public.erp_validate_item_category_assignment();

with unit_names as (
 select distinct company_id,base_unit as unit_name_ar from public.erp_items where nullif(trim(base_unit),'') is not null
), numbered as (
 select company_id,unit_name_ar,'U'||lpad(row_number() over(partition by company_id order by unit_name_ar)::text,3,'0') as unit_code
 from unit_names
)
insert into public.erp_item_unit_catalog(company_id,activity_code,unit_code,unit_name_ar,is_active)
select company_id,'ACT001',unit_code,unit_name_ar,true from numbered
on conflict(company_id,activity_code,unit_code) do update set unit_name_ar=excluded.unit_name_ar,is_active=true,updated_at=now();

create or replace function public.erp_validate_warehouse_parent()
returns trigger language plpgsql set search_path=public as $$
declare parent_company uuid; cycle_found boolean;
begin
 if new.parent_warehouse_id is not null then
  select company_id into parent_company from public.erp_warehouses where id=new.parent_warehouse_id;
  if parent_company is distinct from new.company_id then raise exception 'المخزن الرئيسي يجب أن يتبع الشركة نفسها'; end if;
  if new.parent_warehouse_id = new.id then raise exception 'لا يمكن ربط المخزن بنفسه'; end if;
  with recursive descendants(id,path) as (
   select new.id,array[new.id]::uuid[]
   union all select child.id,d.path||child.id from descendants d
   join public.erp_warehouses child on child.parent_warehouse_id=d.id where not child.id=any(d.path)
  ) select exists(select 1 from descendants where id=new.parent_warehouse_id) into cycle_found;
  if coalesce(cycle_found,false) then raise exception 'لا يمكن وضع المخزن تحت أحد مخازنه الفرعية'; end if;
 end if;
 return new;
end $$;
drop trigger if exists erp_warehouse_parent_guard on public.erp_warehouses;
create trigger erp_warehouse_parent_guard before insert or update of company_id,parent_warehouse_id
on public.erp_warehouses for each row execute function public.erp_validate_warehouse_parent();
