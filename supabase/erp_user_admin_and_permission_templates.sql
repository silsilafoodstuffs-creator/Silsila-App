-- User types, ERP user directory, permission templates, and per-user action matrix.
-- Run after erp_schema.sql and erp_security_membership.sql.
begin;
create table if not exists public.erp_user_types (
 id uuid primary key default gen_random_uuid(),
 company_id uuid not null references public.erp_companies(id) on delete cascade,
type_code bigint generated always as identity,
 type_code_display text not null,
 description text not null default '',
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
 user_code text,
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
create sequence if not exists public.erp_users_user_code_seq;
create or replace function public.erp_assign_user_code()
returns trigger language plpgsql set search_path=public as $
begin
 if new.user_code is null or btrim(new.user_code) = '' then
   new.user_code := 'USR' || lpad(nextval('public.erp_users_user_code_seq')::text,4,'0');
 end if;
 return new;
end;
$;
drop trigger if exists erp_users_assign_user_code on public.erp_users;
create trigger erp_users_assign_user_code before insert on public.erp_users for each row execute function public.erp_assign_user_code();
create table if not exists public.erp_permission_templates (
 id uuid primary key default gen_random_uuid(),
 company_id uuid not null references public.erp_companies(id) on delete cascade,
 template_code bigint generated always as identity,
 template_code_display text not null,
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
 can_access boolean not null default false,
 can_refresh boolean not null default false,
 can_add boolean not null default false,
 can_save boolean not null default false,
 can_edit boolean not null default false,
 can_delete boolean not null default false,
 can_preview boolean not null default false,
 can_print boolean not null default false,
 can_import_excel boolean not null default false,
 can_print_pdf boolean not null default false,
 show_in_quick_tasks boolean not null default false,
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
 show_in_quick_tasks boolean not null default false,
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
drop policy if exists erp_user_types_public_login_read on public.erp_user_types;
create policy erp_user_types_public_login_read on public.erp_user_types for select to anon,authenticated
using (is_active=true and show_at_login=true);
grant select on public.erp_user_types to anon,authenticated;
grant select,insert,update,delete on public.erp_user_types,public.erp_users,public.erp_permission_templates,public.erp_permission_template_rules,public.erp_user_permission_matrix to authenticated;
insert into public.erp_user_types(company_id,name_ar,name_en,is_active,show_at_login)
select c.id,v.name_ar,v.name_en,true,v.show_at_login
from public.erp_companies c
cross join (values
 ('ادمن','Admin',false),('مورد','Supplier',true),('عميل','Customer',true),
 ('شركة شحن','Shipping Company',true),('مندوب','Sales Representative',true)
) as v(name_ar,name_en,show_at_login)
where not exists(select 1 from public.erp_user_types t where t.company_id=c.id and t.name_ar=v.name_ar);

-- Stable per-company display/code order: admin, employee, supplier, customer, delegate, shipping.
alter table public.erp_user_types alter column type_code set generated by default;
update public.erp_user_types set type_code=-type_code;
with ordered_types as (
 select id,row_number() over(partition by company_id order by
  case name_ar when 'ادمن' then 1 when 'موظف' then 2 when 'مورد' then 3
   when 'عميل' then 4 when 'مندوب' then 5 when 'شركة شحن' then 6 else 99 end,
  type_code) as next_code
 from public.erp_user_types
)
update public.erp_user_types t set type_code=o.next_code from ordered_types o where o.id=t.id;
alter table public.erp_user_types alter column type_code set generated always;
select setval(pg_get_serial_sequence('public.erp_user_types','type_code'),
 greatest((select coalesce(max(type_code),1) from public.erp_user_types),1),true);
create or replace function public.erp_seed_default_user_types()
returns trigger language plpgsql security definer set search_path=public as $$
begin
 insert into public.erp_user_types(company_id,name_ar,name_en,is_active,show_at_login)
 values
 (new.id,'ادمن','Admin',true,false),(new.id,'مورد','Supplier',true,true),
 (new.id,'عميل','Customer',true,true),(new.id,'شركة شحن','Shipping Company',true,true),
 (new.id,'مندوب','Sales Representative',true,true)
 on conflict(company_id,name_ar) do nothing;
 return new;
end $$;
drop trigger if exists erp_seed_default_user_types_trigger on public.erp_companies;
create trigger erp_seed_default_user_types_trigger after insert on public.erp_companies for each row execute function public.erp_seed_default_user_types();
update public.erp_user_types set show_at_login=false where name_ar='ادمن' and show_at_login is distinct from false;
commit;

 
-- Mirror existing/new company memberships into the ERP user directory.
create or replace function public.erp_sync_company_member_to_erp_user()
returns trigger language plpgsql security definer set search_path=public as $$
declare v_type_id uuid; v_email text; v_name text;
begin
 select id into v_type_id from public.erp_user_types
 where company_id=new.company_id
 and name_ar=case when new.member_role in ('owner','admin') then 'ادمن' else 'موظف' end
 order by type_code limit 1;
 select email into v_email from auth.users where id=new.user_id;
 v_name:=coalesce(nullif(v_email,''),'مستخدم '||left(new.user_id::text,8));
 insert into public.erp_users(company_id,auth_user_id,name_ar,name_en,user_type_id,is_active)
 values(new.company_id,new.user_id,v_name,coalesce(v_email,''),v_type_id,new.is_active)
 on conflict(company_id,auth_user_id) do update
 set user_type_id=excluded.user_type_id,is_active=excluded.is_active,updated_at=now();
 return new;
end $$;
drop trigger if exists erp_sync_company_member_to_erp_user_trigger on public.erp_company_members;
create trigger erp_sync_company_member_to_erp_user_trigger after insert or update of member_role,is_active
on public.erp_company_members for each row execute function public.erp_sync_company_member_to_erp_user();
insert into public.erp_users(company_id,auth_user_id,name_ar,name_en,user_type_id,is_active)
select m.company_id,m.user_id,coalesce(nullif(u.email,''),'مستخدم '||left(m.user_id::text,8)),coalesce(u.email,''),t.id,m.is_active
from public.erp_company_members m left join auth.users u on u.id=m.user_id
join public.erp_user_types t on t.company_id=m.company_id
and t.name_ar=case when m.member_role in ('owner','admin') then 'ادمن' else 'موظف' end
where not exists(select 1 from public.erp_users eu where eu.company_id=m.company_id and eu.auth_user_id=m.user_id);
