-- User administration: human-readable codes, concise type descriptions, and employee linkage.
begin;

alter table public.erp_user_types
  add column if not exists description text not null default '',
  add column if not exists type_code_display text;

update public.erp_user_types
set type_code_display = 'UT' || lpad(type_code::text, 4, '0')
where type_code_display is null or btrim(type_code_display) = '';

alter table public.erp_user_types
  alter column type_code_display set not null;

create unique index if not exists erp_user_types_company_display_code_uq
  on public.erp_user_types(company_id, type_code_display);

alter table public.erp_permission_templates
  add column if not exists template_code_display text;

update public.erp_permission_templates
set template_code_display = 'PT' || lpad(template_code::text, 4, '0')
where template_code_display is null or btrim(template_code_display) = '';

alter table public.erp_permission_templates
  alter column template_code_display set not null;

create unique index if not exists erp_permission_templates_company_display_code_uq
  on public.erp_permission_templates(company_id, template_code_display);

alter table public.erp_users
  add column if not exists employee_id uuid references public.erp_employees(id) on delete set null;

-- Normalize existing legacy codes without deleting or changing any user identity.
update public.erp_users
set user_code = 'USR' || lpad((substring(user_code from '([0-9]+)$'))::text, 4, '0')
where user_code ~ '^USR-?[0-9]+$'
  and user_code !~ '^USR[0-9]{4,}$';

create or replace function public.erp_assign_user_code()
returns trigger language plpgsql set search_path=public as $$
begin
  if new.user_code is null or btrim(new.user_code) = '' then
    new.user_code := 'USR' || lpad(nextval('public.erp_users_user_code_seq')::text, 4, '0');
  end if;
  return new;
end;
$$;

select setval(
  'public.erp_users_user_code_seq',
  greatest(coalesce((select max((substring(user_code from '([0-9]+)$'))::bigint)
    from public.erp_users where user_code ~ '^USR[0-9]+$'), 0), 1),
  true
);

-- New companies use the requested five business-facing types; keep any existing
-- employee type if it is referenced by a user, so no existing relationship is lost.
create or replace function public.erp_seed_default_user_types()
returns trigger language plpgsql security definer set search_path=public as $$
begin
  insert into public.erp_user_types(company_id,name_ar,name_en,is_active,show_at_login)
  values
    (new.id,'ادمن','Admin',true,false),
    (new.id,'مورد','Supplier',true,true),
    (new.id,'عميل','Customer',true,true),
    (new.id,'شركة شحن','Shipping Company',true,true),
    (new.id,'مندوب','Delegate',true,true)
  on conflict(company_id,name_ar) do nothing;
  return new;
end;
$$;

delete from public.erp_user_types t
where t.name_ar = 'موظف'
  and not exists (select 1 from public.erp_users u where u.user_type_id=t.id);

commit;
