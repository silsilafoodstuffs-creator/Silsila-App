-- User types, ERP user directory, permission templates, and per-user action matrix.
-- Run after erp_schema.sql and erp_security_membership.sql.
begin;
create table if not exists public.erp_user_types (
 id uuid primary key default gen_random_uuid(),
 company_id uuid not null references public.erp_companies(id) on delete cascade,
 type_code bigint generated always as identity,
 name_ar text not null,
 name_en text not null default '',
 image_data text,
 is_active boolean not null default true,
 show_at_login boolean not null default false,
 created_at timestamptz not null default now(),
 updated_at timestamptz not null default now(),
 unique(company_id,type_code),
 unique(company_id,name_ar)
);
create table if not exists public.erp_users (
 id uuid primary key default gen_random_uuid(),
 company_id uuid not null references public.erp_companies(id) on delete cascade,
 user_code bigint generated always as identity,
 auth_user_id uuid references auth.users(id) on delete set null,
 name_ar text not null,
 name_en text not null default '',
 user_type_id uuid references public.erp_user_types(id) on delete set null,
 image_data text,
 is_active boolean not null default true,
 created_at timestamptz not null default now(),
 updated_at timestamptz not null default now(),
 unique(company_id,user_code),
 unique(company_id,auth_user_id)
);
create table if not exists public.erp_permission_templates (
 id uuid primary key default gen_random_uuid(),
 company_id uuid not null references public.erp_companies(id) on delete cascade,
 template_code bigint generated always as identity,
 name_ar text not null,
 name_en text not null default '',
 image_data text,
 is_active boolean not null default true,
 created_at timestamptz not null default now(),
 updated_at timestamptz not null default now(),
 unique(company_id,template_code),
 unique(company_id,name_ar)
);
create table if not exists public.erp_permission_template_rules (
 id uuid primary key default gen_random_uuid(),
 company_id uuid not null references public.erp_companies(id) on delete cascade,
 template_id uuid not null references public.erp_permission_templates(id) on delete cascade,
 menu_name text not null,
 submenu_name text not null default '',
 page_name text not null,
 can_refresh boolean not null default false,
 can_add boolean not null default false,
 can_save boolean not null default false,
 can_edit boolean not null default false,
 can_delete boolean not null default false,
 can_preview boolean not null default false,
 can_print boolean not null default false,
 can_import_excel boolean not null default false,
 can_print_pdf boolean not null default false,
 unique(template_id,menu_name,submenu_name,page_name)
);
create table if not exists public.erp_user_permission_matrix (
 id uuid primary key default gen_random_uuid(),
 company_id uuid not null references public.erp_companies(id) on delete cascade,
 user_id uuid not null references public.erp_users(id) on delete cascade,
 menu_name text not null,
 submenu_name text not null default '',
 page_name text not null,
 can_refresh boolean not null default false,
 can_add boolean not null default false,
 can_save boolean not null default false,
 can_edit boolean not null default false,
 can_delete boolean not null default false,
 can_preview boolean not null default false,
 can_print boolean not null default false,
 can_import_excel boolean not null default false,
 can_print_pdf boolean not null default false,
 updated_at timestamptz not null default now(),
 unique(user_id,menu_name,submenu_name,page_name)
);
create index if not exists erp_user_types_company_idx on public.erp_user_types(company_id,type_code);
create index if not exists erp_users_company_idx on public.erp_users(company_id,user_code);
create index if not exists erp_permission_templates_company_idx on public.erp_permission_templates(company_id,template_code);
create index if not exists erp_user_permission_matrix_user_idx on public.erp_user_permission_matrix(company_id,user_id);
alter table public.erp_user_types enable row level security;
alter table public.erp_users enable row level security;
alter table public.erp_permission_templates enable row level security;
alter table public.erp_permission_template_rules enable row level security;
alter table public.erp_user_permission_matrix enable row level security;
do $$
declare t text;
begin
 foreach t in array array['erp_user_types','erp_users','erp_permission_templates','erp_permission_template_rules','erp_user_permission_matrix'] loop
  execute format('drop policy if exists %I on public.%I',t||'_member_read',t);
  execute format('create policy %I on public.%I for select to authenticated using (public.erp_user_can_access_company(company_id))',t||'_member_read',t);
  execute format('drop policy if exists %I on public.%I',t||'_admin_insert',t);
  execute format('create policy %I on public.%I for insert to authenticated with check (public.erp_user_has_company_role(company_id,array[''owner'',''admin'']::text[]))',t||'_admin_insert',t);
  execute format('drop policy if exists %I on public.%I',t||'_admin_update',t);
  execute format('create policy %I on public.%I for update to authenticated using (public.erp_user_has_company_role(company_id,array[''owner'',''admin'']::text[])) with check (public.erp_user_has_company_role(company_id,array[''owner'',''admin'']::text[]))',t||'_admin_update',t);
  execute format('drop policy if exists %I on public.%I',t||'_admin_delete',t);
  execute format('create policy %I on public.%I for delete to authenticated using (public.erp_user_has_company_role(company_id,array[''owner'',''admin'']::text[]))',t||'_admin_delete',t);
 end loop;
end $$;
grant select,insert,update,delete on public.erp_user_types,public.erp_users,public.erp_permission_templates,public.erp_permission_template_rules,public.erp_user_permission_matrix to authenticated;
insert into public.erp_user_types(company_id,name_ar,name_en,is_active,show_at_login)
select c.id,v.name_ar,v.name_en,true,v.show_at_login
from public.erp_companies c
cross join (values
 ('ادمن','Admin',false),('موظف','Employee',false),('مورد','Supplier',true),
 ('عميل','Customer',true),('مندوب','Delegate',true),('شركة شحن','Shipping Company',true)
) as v(name_ar,name_en,show_at_login)
where not exists(select 1 from public.erp_user_types t where t.company_id=c.id and t.name_ar=v.name_ar);
create or replace function public.erp_seed_default_user_types()
returns trigger language plpgsql security definer set search_path=public as $$
begin
 insert into public.erp_user_types(company_id,name_ar,name_en,is_active,show_at_login)
 values
 (new.id,'ادمن','Admin',true,false),(new.id,'موظف','Employee',true,false),
 (new.id,'مورد','Supplier',true,true),(new.id,'عميل','Customer',true,true),
 (new.id,'مندوب','Delegate',true,true),(new.id,'شركة شحن','Shipping Company',true,true)
 on conflict(company_id,name_ar) do nothing;
 return new;
end $$;
drop trigger if exists erp_seed_default_user_types_trigger on public.erp_companies;
create trigger erp_seed_default_user_types_trigger after insert on public.erp_companies for each row execute function public.erp_seed_default_user_types();
commit;
