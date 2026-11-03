create table if not exists public.erp_business_workspace_counterparties (
 id uuid primary key default gen_random_uuid(),
 workspace_id uuid not null references public.erp_business_workspaces(id) on delete cascade,
 party_type text not null check (party_type in ('customer','supplier')),
 party_code text not null,
 display_name text not null check (length(trim(display_name)) between 2 and 180),
 phone text, address text, governorate text, district text, area text, notes text,
 is_active boolean not null default true,
 created_by uuid not null references auth.users(id),
 created_at timestamptz not null default now(),
 updated_at timestamptz not null default now(),
 unique(workspace_id,party_type,party_code)
);
create index if not exists erp_ws_counterparties_phone_idx on public.erp_business_workspace_counterparties(workspace_id,party_type,phone);
create index if not exists erp_ws_counterparties_name_idx on public.erp_business_workspace_counterparties(workspace_id,party_type,display_name);
alter table public.erp_business_workspace_counterparties enable row level security;
drop policy if exists erp_ws_counterparties_read on public.erp_business_workspace_counterparties;
create policy erp_ws_counterparties_read on public.erp_business_workspace_counterparties for select to authenticated
using (private.can_access_business_workspace(workspace_id,case when party_type='customer' then 'customers.read' else 'suppliers.read' end));
drop policy if exists erp_ws_counterparties_insert on public.erp_business_workspace_counterparties;
create policy erp_ws_counterparties_insert on public.erp_business_workspace_counterparties for insert to authenticated
with check ((select auth.uid())=created_by and private.can_access_business_workspace(workspace_id,case when party_type='customer' then 'customers.manage' else 'suppliers.manage' end));
drop policy if exists erp_ws_counterparties_update on public.erp_business_workspace_counterparties;
create policy erp_ws_counterparties_update on public.erp_business_workspace_counterparties for update to authenticated
using (private.can_access_business_workspace(workspace_id,case when party_type='customer' then 'customers.manage' else 'suppliers.manage' end))
with check (private.can_access_business_workspace(workspace_id,case when party_type='customer' then 'customers.manage' else 'suppliers.manage' end));
grant select,insert,update on public.erp_business_workspace_counterparties to authenticated;
revoke all on public.erp_business_workspace_counterparties from anon;

create or replace function private.find_silsila_profile_by_phone(p_workspace_id uuid,p_phone text)
returns table(profile_name text,profile_phone text,account_type text)
language plpgsql stable security definer
set search_path=pg_catalog,public,auth,private
as $$
declare v_phone text:=regexp_replace(coalesce(p_phone,''),'[^0-9+]','','g');
begin
 if (select auth.uid()) is null then raise exception 'Authentication required' using errcode='28000'; end if;
 if not (private.can_access_business_workspace(p_workspace_id,'customers.read') or private.can_access_business_workspace(p_workspace_id,'suppliers.read')) then
  raise exception 'Insufficient permission to preview Silsila contact matches' using errcode='42501';
 end if;
 if length(regexp_replace(v_phone,'[^0-9]','','g')) < 10 then return; end if;
 return query select p.full_name,p.phone,p.account_type from public.profiles p
 where regexp_replace(coalesce(p.phone,''),'[^0-9+]','','g')=v_phone
    or regexp_replace(coalesce(p.whatsapp_phone,''),'[^0-9+]','','g')=v_phone limit 1;
end $$;
revoke all on function private.find_silsila_profile_by_phone(uuid,text) from public,anon;
grant execute on function private.find_silsila_profile_by_phone(uuid,text) to authenticated;
create or replace function public.erp_find_silsila_profile_by_phone(p_workspace_id uuid,p_phone text)
returns table(profile_name text,profile_phone text,account_type text)
language sql stable security invoker
set search_path=pg_catalog,public,auth,private
as $$ select * from private.find_silsila_profile_by_phone(p_workspace_id,p_phone); $$;
revoke all on function public.erp_find_silsila_profile_by_phone(uuid,text) from public,anon;
grant execute on function public.erp_find_silsila_profile_by_phone(uuid,text) to authenticated;
