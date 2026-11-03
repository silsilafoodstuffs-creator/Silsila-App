-- Independent business workspaces for customer and supplier accounts.
-- Tenant data is isolated from the central Silsila ERP company.
begin;
create schema if not exists private;
revoke all on schema private from public, anon;
grant usage on schema private to authenticated;

create table if not exists public.erp_business_workspaces (
 id uuid primary key default gen_random_uuid(),
 owner_user_id uuid not null references auth.users(id) on delete restrict,
 linked_profile_id uuid references public.profiles(id) on delete set null,
 workspace_name text not null check(length(trim(workspace_name)) between 2 and 160),
 activity_type text,
 account_kind text not null default 'customer' check(account_kind in ('customer','supplier','other')),
 is_active boolean not null default true,
 settings jsonb not null default '{}'::jsonb,
 created_at timestamptz not null default now(),
 updated_at timestamptz not null default now()
);
create index if not exists erp_business_workspaces_owner_idx on public.erp_business_workspaces(owner_user_id);
create index if not exists erp_business_workspaces_profile_idx on public.erp_business_workspaces(linked_profile_id);

create table if not exists public.erp_business_workspace_members (
 id uuid primary key default gen_random_uuid(),
 workspace_id uuid not null references public.erp_business_workspaces(id) on delete cascade,
 user_id uuid not null references auth.users(id) on delete cascade,
 member_role text not null default 'staff' check(member_role in ('owner','admin','manager','accountant','warehouse','sales','viewer','staff')),
 is_active boolean not null default true,
 can_open_workspace boolean not null default true,
 permissions jsonb not null default '{}'::jsonb,
 created_by uuid references auth.users(id) on delete set null,
 created_at timestamptz not null default now(),
 updated_at timestamptz not null default now(),
 unique(workspace_id,user_id)
);
create index if not exists erp_business_workspace_members_user_idx on public.erp_business_workspace_members(user_id,workspace_id);

create or replace function private.can_access_business_workspace(
 p_workspace_id uuid,
 p_permission text default 'workspace.enter'
) returns boolean
language sql
stable
security definer
set search_path = ''
as $function$
  select case
    when private.is_silsila_workspace_observer() then
      p_permission = any(array[
        'workspace.enter','master.read','items.read','inventory.read',
        'purchases.read','sales.read','cash.read','hr.read','reports.read',
        'members.read','audit.read','customers.read','suppliers.read'
      ]::text[])
      and exists (
        select 1 from public.erp_business_workspaces w
        where w.id=p_workspace_id and w.is_active
      )
    else
      exists (
        select 1
        from public.erp_business_workspaces w
        where w.id=p_workspace_id and w.is_active
          and (
            w.owner_user_id=(select auth.uid())
            or exists (
              select 1
              from public.erp_business_workspace_members m
              where m.workspace_id=w.id
                and m.user_id=(select auth.uid())
                and m.is_active
                and m.can_open_workspace
                and (
                  m.member_role in ('owner','admin')
                  or m.permissions->>p_permission='true'
                  or m.permissions->>'*'='true'
                  or (p_permission like '%.read'
                      and m.permissions->>replace(p_permission,'.read','.manage')='true')
                )
            )
          )
      )
  end;
$function$;
revoke all on function private.can_access_business_workspace(uuid,text) from public,anon;
grant execute on function private.can_access_business_workspace(uuid,text) to authenticated;

create or replace function private.add_business_workspace_owner()
returns trigger language plpgsql security definer
set search_path=pg_catalog,public,auth,private as $$
begin
 insert into public.erp_business_workspace_members(workspace_id,user_id,member_role,is_active,can_open_workspace,permissions,created_by)
 values(new.id,new.owner_user_id,'owner',true,true,'{"*":true}'::jsonb,new.owner_user_id)
 on conflict(workspace_id,user_id) do update set member_role='owner',is_active=true,can_open_workspace=true,permissions='{"*":true}'::jsonb;
 return new;
end $$;
revoke all on function private.add_business_workspace_owner() from public,anon,authenticated;
drop trigger if exists erp_business_workspace_owner_member on public.erp_business_workspaces;
create trigger erp_business_workspace_owner_member after insert on public.erp_business_workspaces
for each row execute function private.add_business_workspace_owner();

create table if not exists public.erp_business_workspace_branches (
 id uuid primary key default gen_random_uuid(), workspace_id uuid not null references public.erp_business_workspaces(id) on delete cascade,
 branch_code text not null, name_ar text not null, name_en text, is_active boolean not null default true,
 created_at timestamptz not null default now(), unique(workspace_id,branch_code)
);
create table if not exists public.erp_business_workspace_warehouses (
 id uuid primary key default gen_random_uuid(), workspace_id uuid not null references public.erp_business_workspaces(id) on delete cascade,
 branch_id uuid not null references public.erp_business_workspace_branches(id) on delete restrict,
 warehouse_code text not null, name_ar text not null, name_en text,
 show_balance_in_silsila boolean not null default false, is_active boolean not null default true,
 created_at timestamptz not null default now(), unique(workspace_id,warehouse_code)
);
create index if not exists erp_business_warehouses_branch_idx on public.erp_business_workspace_warehouses(workspace_id,branch_id);

create table if not exists public.erp_business_workspace_item_links (
 id uuid primary key default gen_random_uuid(), workspace_id uuid not null references public.erp_business_workspaces(id) on delete cascade,
 platform_item_id uuid not null references public.erp_items(id) on delete restrict, is_enabled boolean not null default true,
 local_code text, reorder_level numeric(18,4) not null default 0 check(reorder_level>=0),
 created_at timestamptz not null default now(), unique(workspace_id,platform_item_id)
);
create table if not exists public.erp_business_workspace_item_proposals (
 id uuid primary key default gen_random_uuid(), workspace_id uuid not null references public.erp_business_workspaces(id) on delete cascade,
 proposed_by uuid not null references auth.users(id), name_ar text not null, name_en text, proposed_category text,
 unit_name text not null default 'قطعة', description text, payload jsonb not null default '{}'::jsonb,
 status text not null default 'pending' check(status in ('pending','approved','rejected','cancelled')),
 reviewed_by uuid references auth.users(id), reviewed_at timestamptz, platform_item_id uuid references public.erp_items(id),
 review_note text, created_at timestamptz not null default now()
);
create index if not exists erp_business_item_proposals_workspace_idx on public.erp_business_workspace_item_proposals(workspace_id,status,created_at desc);

create table if not exists public.erp_business_workspace_stock_openings (
 id uuid primary key default gen_random_uuid(), workspace_id uuid not null references public.erp_business_workspaces(id) on delete cascade,
 warehouse_id uuid not null references public.erp_business_workspace_warehouses(id) on delete restrict,
 item_link_id uuid not null references public.erp_business_workspace_item_links(id) on delete restrict,
 quantity numeric(18,4) not null check(quantity>=0), unit_cost numeric(18,4) not null default 0 check(unit_cost>=0),
 opening_date date not null default current_date, created_by uuid not null references auth.users(id),
 created_at timestamptz not null default now(), unique(workspace_id,warehouse_id,item_link_id)
);

create table if not exists public.erp_business_workspace_documents (
 id uuid primary key default gen_random_uuid(), workspace_id uuid not null references public.erp_business_workspaces(id) on delete cascade,
 branch_id uuid references public.erp_business_workspace_branches(id) on delete restrict,
 warehouse_id uuid references public.erp_business_workspace_warehouses(id) on delete restrict,
 document_no text not null, document_type text not null check(document_type in ('purchase','purchase_return','sale','sale_return','transfer','adjustment')),
 document_date date not null default current_date, counterparty_name text, notes text,
 status text not null default 'draft' check(status in ('draft','pending','posted','cancelled')),
 subtotal numeric(18,4) not null default 0, discount numeric(18,4) not null default 0,
 tax numeric(18,4) not null default 0, total numeric(18,4) not null default 0,
 created_by uuid not null references auth.users(id), posted_by uuid references auth.users(id), posted_at timestamptz,
 created_at timestamptz not null default now(), updated_at timestamptz not null default now(),
 unique(workspace_id,document_no)
);
create index if not exists erp_business_documents_date_idx on public.erp_business_workspace_documents(workspace_id,document_date desc,document_type);
create table if not exists public.erp_business_workspace_document_lines (
 id uuid primary key default gen_random_uuid(), workspace_id uuid not null references public.erp_business_workspaces(id) on delete cascade,
 document_id uuid not null references public.erp_business_workspace_documents(id) on delete cascade,
 item_link_id uuid not null references public.erp_business_workspace_item_links(id) on delete restrict,
 warehouse_id uuid references public.erp_business_workspace_warehouses(id) on delete restrict,
 quantity numeric(18,4) not null check(quantity>0), unit_price numeric(18,4) not null default 0 check(unit_price>=0),
 discount numeric(18,4) not null default 0 check(discount>=0), line_total numeric(18,4) not null default 0,
 created_at timestamptz not null default now()
);
create index if not exists erp_business_document_lines_document_idx on public.erp_business_workspace_document_lines(workspace_id,document_id);

create table if not exists public.erp_business_workspace_stock_movements (
 id uuid primary key default gen_random_uuid(), workspace_id uuid not null references public.erp_business_workspaces(id) on delete cascade,
 warehouse_id uuid not null references public.erp_business_workspace_warehouses(id) on delete restrict,
 item_link_id uuid not null references public.erp_business_workspace_item_links(id) on delete restrict,
 document_id uuid references public.erp_business_workspace_documents(id) on delete restrict,
 movement_type text not null check(movement_type in ('opening','purchase','purchase_return','sale','sale_return','transfer_in','transfer_out','adjustment_in','adjustment_out')),
 quantity_in numeric(18,4) not null default 0 check(quantity_in>=0), quantity_out numeric(18,4) not null default 0 check(quantity_out>=0),
 unit_cost numeric(18,4) not null default 0 check(unit_cost>=0), movement_date date not null default current_date,
 created_by uuid not null references auth.users(id), created_at timestamptz not null default now(),
 check(quantity_in=0 or quantity_out=0)
);
create index if not exists erp_business_stock_balance_idx on public.erp_business_workspace_stock_movements(workspace_id,warehouse_id,item_link_id,movement_date);

create table if not exists public.erp_business_workspace_cash_movements (
 id uuid primary key default gen_random_uuid(), workspace_id uuid not null references public.erp_business_workspaces(id) on delete cascade,
 branch_id uuid references public.erp_business_workspace_branches(id) on delete restrict,
 movement_no text not null, movement_type text not null check(movement_type in ('receipt','payment','deposit','expense','income','transfer_in','transfer_out')),
 movement_date date not null default current_date, amount numeric(18,4) not null check(amount>0),
 description text not null, counterparty_name text, payment_method text, reference_no text,
 created_by uuid not null references auth.users(id), created_at timestamptz not null default now(),
 unique(workspace_id,movement_no)
);
create index if not exists erp_business_cash_movements_date_idx on public.erp_business_workspace_cash_movements(workspace_id,movement_date desc);

create table if not exists public.erp_business_workspace_departments (
 id uuid primary key default gen_random_uuid(), workspace_id uuid not null references public.erp_business_workspaces(id) on delete cascade,
 parent_id uuid references public.erp_business_workspace_departments(id) on delete restrict,
 department_code text not null, name_ar text not null, is_active boolean not null default true, unique(workspace_id,department_code)
);
create table if not exists public.erp_business_workspace_employees (
 id uuid primary key default gen_random_uuid(), workspace_id uuid not null references public.erp_business_workspaces(id) on delete cascade,
 department_id uuid references public.erp_business_workspace_departments(id) on delete set null,
 employee_code text not null, full_name text not null, job_title text,
 monthly_salary numeric(18,4) not null default 0 check(monthly_salary>=0),
 work_schedule jsonb not null default '{}'::jsonb, leave_policy jsonb not null default '{}'::jsonb,
 is_active boolean not null default true, created_at timestamptz not null default now(), unique(workspace_id,employee_code)
);
create table if not exists public.erp_business_workspace_audit_log (
 id bigint generated always as identity primary key, workspace_id uuid not null references public.erp_business_workspaces(id) on delete cascade,
 actor_user_id uuid references auth.users(id) on delete set null, action text not null, entity_type text not null,
 entity_id text, details jsonb not null default '{}'::jsonb, created_at timestamptz not null default now()
);
create index if not exists erp_business_workspace_audit_idx on public.erp_business_workspace_audit_log(workspace_id,created_at desc);

do $$ declare r record; begin
 for r in select * from (values
 ('erp_business_workspace_members','members.read','members.manage'),
 ('erp_business_workspace_branches','master.read','master.manage'),
 ('erp_business_workspace_warehouses','master.read','master.manage'),
 ('erp_business_workspace_item_links','master.read','master.manage'),
 ('erp_business_workspace_item_proposals','items.read','items.propose'),
 ('erp_business_workspace_stock_openings','inventory.read','inventory.manage'),
 ('erp_business_workspace_documents','documents.read','documents.manage'),
 ('erp_business_workspace_document_lines','documents.read','documents.manage'),
 ('erp_business_workspace_stock_movements','inventory.read','inventory.manage'),
 ('erp_business_workspace_cash_movements','cash.read','cash.manage'),
 ('erp_business_workspace_departments','hr.read','hr.manage'),
 ('erp_business_workspace_employees','hr.read','hr.manage'),
 ('erp_business_workspace_audit_log','audit.read','audit.write')
 ) as p(tbl,read_perm,write_perm) loop
  execute format('alter table public.%I enable row level security',r.tbl);
  execute format('revoke all on public.%I from anon',r.tbl);
  execute format('grant select,insert,update,delete on public.%I to authenticated',r.tbl);
  execute format('drop policy if exists workspace_select on public.%I',r.tbl);
  execute format('drop policy if exists workspace_insert on public.%I',r.tbl);
  execute format('drop policy if exists workspace_update on public.%I',r.tbl);
  execute format('drop policy if exists workspace_delete on public.%I',r.tbl);
  execute format('create policy workspace_select on public.%I for select to authenticated using(private.can_access_business_workspace(workspace_id,%L))',r.tbl,r.read_perm);
  execute format('create policy workspace_insert on public.%I for insert to authenticated with check(private.can_access_business_workspace(workspace_id,%L))',r.tbl,r.write_perm);
  execute format('create policy workspace_update on public.%I for update to authenticated using(private.can_access_business_workspace(workspace_id,%L)) with check(private.can_access_business_workspace(workspace_id,%L))',r.tbl,r.write_perm,r.write_perm);
  execute format('create policy workspace_delete on public.%I for delete to authenticated using(private.can_access_business_workspace(workspace_id,%L))',r.tbl,r.write_perm);
 end loop;
end $$;

alter table public.erp_business_workspaces enable row level security;
revoke all on public.erp_business_workspaces from anon;
grant select,insert,update on public.erp_business_workspaces to authenticated;
drop policy if exists business_workspace_select on public.erp_business_workspaces;
create policy business_workspace_select on public.erp_business_workspaces for select to authenticated using(private.can_access_business_workspace(id,'workspace.enter'));
drop policy if exists business_workspace_insert on public.erp_business_workspaces;
create policy business_workspace_insert on public.erp_business_workspaces for insert to authenticated with check(owner_user_id=(select auth.uid()));
drop policy if exists business_workspace_update on public.erp_business_workspaces;
create policy business_workspace_update on public.erp_business_workspaces for update to authenticated using(owner_user_id=(select auth.uid())) with check(owner_user_id=(select auth.uid()));
revoke all on sequence public.erp_business_workspace_audit_log_id_seq from anon,authenticated;
commit;

 
-- Final hardening: do not restore self-service workspace creation when this
-- legacy bootstrap script is reapplied. Only the approved-profile trigger
-- provisions a workspace. Platform observers remain read-only.
drop policy if exists business_workspace_insert on public.erp_business_workspaces;
revoke insert, delete, truncate, references, trigger on public.erp_business_workspaces from authenticated, anon;
grant select, update on public.erp_business_workspaces to authenticated;
drop policy if exists business_workspace_update on public.erp_business_workspaces;
create policy business_workspace_update
on public.erp_business_workspaces
for update to authenticated
using (private.is_business_workspace_owner(id))
with check (private.is_business_workspace_owner(id));
