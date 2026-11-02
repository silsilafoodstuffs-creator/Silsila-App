create table if not exists public.erp_business_workspace_member_locations(
 id uuid primary key default gen_random_uuid(),
 workspace_id uuid not null references public.erp_business_workspaces(id) on delete cascade,
 user_id uuid not null references auth.users(id) on delete cascade,
 access_scope text not null check(access_scope in ('branch','warehouse')),
 branch_id uuid,warehouse_id uuid,is_allowed boolean not null default true,
 created_at timestamptz not null default now(),updated_at timestamptz not null default now(),
 constraint biz_member_location_branch_fk foreign key(branch_id,workspace_id) references public.erp_business_workspace_branches(id,workspace_id) on delete cascade,
 constraint biz_member_location_warehouse_fk foreign key(warehouse_id,workspace_id) references public.erp_business_workspace_warehouses(id,workspace_id) on delete cascade,
 constraint biz_member_location_scope_check check((access_scope='branch' and branch_id is not null and warehouse_id is null) or (access_scope='warehouse' and warehouse_id is not null))
);
create unique index if not exists erp_biz_member_branch_scope_uk on public.erp_business_workspace_member_locations(workspace_id,user_id,branch_id) where access_scope='branch';
create unique index if not exists erp_biz_member_warehouse_scope_uk on public.erp_business_workspace_member_locations(workspace_id,user_id,warehouse_id) where access_scope='warehouse';
create index if not exists erp_biz_member_locations_user_idx on public.erp_business_workspace_member_locations(workspace_id,user_id);
create index if not exists erp_biz_member_locations_user_fk_idx on public.erp_business_workspace_member_locations(user_id);
create index if not exists erp_biz_member_locations_branch_fk_idx on public.erp_business_workspace_member_locations(branch_id,workspace_id) where branch_id is not null;
create index if not exists erp_biz_member_locations_warehouse_fk_idx on public.erp_business_workspace_member_locations(warehouse_id,workspace_id) where warehouse_id is not null;
alter table public.erp_business_workspace_member_locations enable row level security;
grant select,insert,update,delete on public.erp_business_workspace_member_locations to authenticated;
drop policy if exists workspace_select on public.erp_business_workspace_member_locations;
create policy workspace_select on public.erp_business_workspace_member_locations for select to authenticated using(private.is_business_workspace_owner(workspace_id) or private.can_access_business_workspace(workspace_id,'members.read'));
drop policy if exists workspace_insert on public.erp_business_workspace_member_locations;
create policy workspace_insert on public.erp_business_workspace_member_locations for insert to authenticated with check(private.is_business_workspace_owner(workspace_id));
drop policy if exists workspace_update on public.erp_business_workspace_member_locations;
create policy workspace_update on public.erp_business_workspace_member_locations for update to authenticated using(private.is_business_workspace_owner(workspace_id)) with check(private.is_business_workspace_owner(workspace_id));
drop policy if exists workspace_delete on public.erp_business_workspace_member_locations;
create policy workspace_delete on public.erp_business_workspace_member_locations for delete to authenticated using(private.is_business_workspace_owner(workspace_id));

create or replace function private.can_access_business_workspace_location(p_workspace_id uuid,p_branch_id uuid default null,p_warehouse_id uuid default null)
returns boolean language plpgsql stable security definer set search_path=pg_catalog,public,auth,private
as $$
declare v_user uuid:=(select auth.uid()); v_branch uuid:=p_branch_id; v_has_rules boolean; v_has_allow_rules boolean; v_has_allowed_warehouse boolean;
begin
 if v_user is null then return false; end if;
 if exists(select 1 from public.erp_business_workspaces w where w.id=p_workspace_id and w.owner_user_id=v_user and w.is_active) then return true; end if;
 if not exists(select 1 from public.erp_business_workspace_members m where m.workspace_id=p_workspace_id and m.user_id=v_user and m.is_active and m.can_open_workspace) then return false; end if;
 if p_branch_id is not null and not exists(select 1 from public.erp_business_workspace_branches b where b.id=p_branch_id and b.workspace_id=p_workspace_id and b.is_active) then return false; end if;
 if p_warehouse_id is not null and not exists(select 1 from public.erp_business_workspace_warehouses w where w.id=p_warehouse_id and w.workspace_id=p_workspace_id and w.is_active) then return false; end if;
 if v_branch is null and p_warehouse_id is not null then select branch_id into v_branch from public.erp_business_workspace_warehouses where id=p_warehouse_id and workspace_id=p_workspace_id; end if;
 select exists(select 1 from public.erp_business_workspace_member_locations l where l.workspace_id=p_workspace_id and l.user_id=v_user),
        exists(select 1 from public.erp_business_workspace_member_locations l where l.workspace_id=p_workspace_id and l.user_id=v_user and l.is_allowed)
 into v_has_rules,v_has_allow_rules;
 if not v_has_rules then return true; end if;
 select exists(select 1 from public.erp_business_workspace_member_locations l join public.erp_business_workspace_warehouses wh on wh.id=l.warehouse_id and wh.workspace_id=l.workspace_id
  where l.workspace_id=p_workspace_id and l.user_id=v_user and l.access_scope='warehouse' and l.is_allowed
   and ((p_warehouse_id is not null and l.warehouse_id=p_warehouse_id) or (p_warehouse_id is null and wh.branch_id=v_branch)))
 into v_has_allowed_warehouse;
 if exists(select 1 from public.erp_business_workspace_member_locations l where l.workspace_id=p_workspace_id and l.user_id=v_user and l.access_scope='warehouse' and l.warehouse_id=p_warehouse_id and not l.is_allowed) then return false; end if;
 if exists(select 1 from public.erp_business_workspace_member_locations l where l.workspace_id=p_workspace_id and l.user_id=v_user and l.access_scope='branch' and l.branch_id=v_branch and not l.is_allowed) and not v_has_allowed_warehouse then return false; end if;
 if not v_has_allow_rules then return true; end if;
 return exists(select 1 from public.erp_business_workspace_member_locations l where l.workspace_id=p_workspace_id and l.user_id=v_user and l.access_scope='branch' and l.branch_id=v_branch and l.is_allowed)
  or exists(select 1 from public.erp_business_workspace_member_locations l where l.workspace_id=p_workspace_id and l.user_id=v_user and l.access_scope='warehouse' and l.warehouse_id=p_warehouse_id and l.is_allowed)
  or (p_warehouse_id is null and v_has_allowed_warehouse);
end $$;
revoke all on function private.can_access_business_workspace_location(uuid,uuid,uuid) from public,anon;
grant execute on function private.can_access_business_workspace_location(uuid,uuid,uuid) to authenticated;

create or replace function public.erp_set_business_workspace_location_access(p_workspace_id uuid,p_user_id uuid,p_access_scope text,p_branch_id uuid,p_warehouse_id uuid,p_is_allowed boolean)
returns uuid language plpgsql security invoker set search_path=pg_catalog,public,auth,private
as $$
declare v_id uuid;
begin
 if (select auth.uid()) is null then raise exception 'Authentication required' using errcode='28000'; end if;
 if not private.is_business_workspace_owner(p_workspace_id) then raise exception 'Only the workspace owner can set location access' using errcode='42501'; end if;
 if not exists(select 1 from public.erp_business_workspace_members m where m.workspace_id=p_workspace_id and m.user_id=p_user_id and m.is_active and m.member_role<>'owner') then raise exception 'Member is not active in this workspace' using errcode='P0002'; end if;
 if p_access_scope='branch' then
  if p_branch_id is null or p_warehouse_id is not null or not exists(select 1 from public.erp_business_workspace_branches b where b.id=p_branch_id and b.workspace_id=p_workspace_id) then raise exception 'Invalid branch access target' using errcode='22023'; end if;
  insert into public.erp_business_workspace_member_locations(workspace_id,user_id,access_scope,branch_id,warehouse_id,is_allowed) values(p_workspace_id,p_user_id,'branch',p_branch_id,null,coalesce(p_is_allowed,false))
  on conflict(workspace_id,user_id,branch_id) where access_scope='branch' do update set is_allowed=excluded.is_allowed,updated_at=now() returning id into v_id;
 elsif p_access_scope='warehouse' then
  if p_warehouse_id is null or not exists(select 1 from public.erp_business_workspace_warehouses w where w.id=p_warehouse_id and w.workspace_id=p_workspace_id) then raise exception 'Invalid warehouse access target' using errcode='22023'; end if;
  insert into public.erp_business_workspace_member_locations(workspace_id,user_id,access_scope,branch_id,warehouse_id,is_allowed) values(p_workspace_id,p_user_id,'warehouse',p_branch_id,p_warehouse_id,coalesce(p_is_allowed,false))
  on conflict(workspace_id,user_id,warehouse_id) where access_scope='warehouse' do update set is_allowed=excluded.is_allowed,branch_id=excluded.branch_id,updated_at=now() returning id into v_id;
 else raise exception 'Access scope must be branch or warehouse' using errcode='22023';
 end if;
 return v_id;
end $$;
revoke all on function public.erp_set_business_workspace_location_access(uuid,uuid,text,uuid,uuid,boolean) from public,anon;
grant execute on function public.erp_set_business_workspace_location_access(uuid,uuid,text,uuid,uuid,boolean) to authenticated;

alter policy workspace_select on public.erp_business_workspace_branches using(private.can_access_business_workspace(workspace_id,'master.read') and private.can_access_business_workspace_location(workspace_id,id,null));
alter policy workspace_insert on public.erp_business_workspace_branches with check(private.can_access_business_workspace(workspace_id,'master.manage') and private.can_access_business_workspace_location(workspace_id,id,null));
alter policy workspace_update on public.erp_business_workspace_branches using(private.can_access_business_workspace(workspace_id,'master.manage') and private.can_access_business_workspace_location(workspace_id,id,null)) with check(private.can_access_business_workspace(workspace_id,'master.manage') and private.can_access_business_workspace_location(workspace_id,id,null));
alter policy workspace_delete on public.erp_business_workspace_branches using(private.can_access_business_workspace(workspace_id,'master.manage') and private.can_access_business_workspace_location(workspace_id,id,null));

alter policy workspace_select on public.erp_business_workspace_warehouses using(private.can_access_business_workspace(workspace_id,'master.read') and private.can_access_business_workspace_location(workspace_id,branch_id,id));
alter policy workspace_insert on public.erp_business_workspace_warehouses with check(private.can_access_business_workspace(workspace_id,'master.manage') and private.can_access_business_workspace_location(workspace_id,branch_id,id));
alter policy workspace_update on public.erp_business_workspace_warehouses using(private.can_access_business_workspace(workspace_id,'master.manage') and private.can_access_business_workspace_location(workspace_id,branch_id,id)) with check(private.can_access_business_workspace(workspace_id,'master.manage') and private.can_access_business_workspace_location(workspace_id,branch_id,id));
alter policy workspace_delete on public.erp_business_workspace_warehouses using(private.can_access_business_workspace(workspace_id,'master.manage') and private.can_access_business_workspace_location(workspace_id,branch_id,id));

alter policy workspace_select on public.erp_business_workspace_cash_movements using(private.can_access_business_workspace(workspace_id,'cash.read') and private.can_access_business_workspace_location(workspace_id,branch_id,null));
alter policy workspace_insert on public.erp_business_workspace_cash_movements with check(private.can_access_business_workspace(workspace_id,'cash.manage') and private.can_access_business_workspace_location(workspace_id,branch_id,null));
alter policy workspace_update on public.erp_business_workspace_cash_movements using(private.can_access_business_workspace(workspace_id,'cash.manage') and private.can_access_business_workspace_location(workspace_id,branch_id,null)) with check(private.can_access_business_workspace(workspace_id,'cash.manage') and private.can_access_business_workspace_location(workspace_id,branch_id,null));
alter policy workspace_delete on public.erp_business_workspace_cash_movements using(private.can_access_business_workspace(workspace_id,'cash.manage') and private.can_access_business_workspace_location(workspace_id,branch_id,null));

alter policy workspace_select on public.erp_business_workspace_documents using(private.can_access_business_workspace(workspace_id,case when document_type in ('purchase','purchase_return') then 'purchases.read' when document_type in ('sale','sale_return') then 'sales.read' else 'inventory.read' end) and private.can_access_business_workspace_location(workspace_id,branch_id,warehouse_id));
alter policy workspace_insert on public.erp_business_workspace_documents with check(private.can_access_business_workspace(workspace_id,case when document_type in ('purchase','purchase_return') then 'purchases.manage' when document_type in ('sale','sale_return') then 'sales.manage' else 'inventory.manage' end) and private.can_access_business_workspace_location(workspace_id,branch_id,warehouse_id));
alter policy workspace_update on public.erp_business_workspace_documents using(private.can_access_business_workspace(workspace_id,case when document_type in ('purchase','purchase_return') then 'purchases.manage' when document_type in ('sale','sale_return') then 'sales.manage' else 'inventory.manage' end) and private.can_access_business_workspace_location(workspace_id,branch_id,warehouse_id)) with check(private.can_access_business_workspace(workspace_id,case when document_type in ('purchase','purchase_return') then 'purchases.manage' when document_type in ('sale','sale_return') then 'sales.manage' else 'inventory.manage' end) and private.can_access_business_workspace_location(workspace_id,branch_id,warehouse_id));
alter policy workspace_delete on public.erp_business_workspace_documents using(status='draft' and private.can_access_business_workspace(workspace_id,case when document_type in ('purchase','purchase_return') then 'purchases.manage' when document_type in ('sale','sale_return') then 'sales.manage' else 'inventory.manage' end) and private.can_access_business_workspace_location(workspace_id,branch_id,warehouse_id));

alter policy workspace_select on public.erp_business_workspace_document_lines using(exists(select 1 from public.erp_business_workspace_documents d where d.id=erp_business_workspace_document_lines.document_id and d.workspace_id=erp_business_workspace_document_lines.workspace_id and private.can_access_business_workspace(d.workspace_id,case when d.document_type in ('purchase','purchase_return') then 'purchases.read' when d.document_type in ('sale','sale_return') then 'sales.read' else 'inventory.read' end) and private.can_access_business_workspace_location(d.workspace_id,d.branch_id,erp_business_workspace_document_lines.warehouse_id)));
alter policy workspace_insert on public.erp_business_workspace_document_lines with check(exists(select 1 from public.erp_business_workspace_documents d where d.id=erp_business_workspace_document_lines.document_id and d.workspace_id=erp_business_workspace_document_lines.workspace_id and d.status='draft' and private.can_access_business_workspace(d.workspace_id,case when d.document_type in ('purchase','purchase_return') then 'purchases.manage' when d.document_type in ('sale','sale_return') then 'sales.manage' else 'inventory.manage' end) and private.can_access_business_workspace_location(d.workspace_id,d.branch_id,erp_business_workspace_document_lines.warehouse_id)));
alter policy workspace_update on public.erp_business_workspace_document_lines using(exists(select 1 from public.erp_business_workspace_documents d where d.id=erp_business_workspace_document_lines.document_id and d.workspace_id=erp_business_workspace_document_lines.workspace_id and d.status='draft' and private.can_access_business_workspace(d.workspace_id,case when d.document_type in ('purchase','purchase_return') then 'purchases.manage' when d.document_type in ('sale','sale_return') then 'sales.manage' else 'inventory.manage' end) and private.can_access_business_workspace_location(d.workspace_id,d.branch_id,erp_business_workspace_document_lines.warehouse_id))) with check(exists(select 1 from public.erp_business_workspace_documents d where d.id=erp_business_workspace_document_lines.document_id and d.workspace_id=erp_business_workspace_document_lines.workspace_id and d.status='draft' and private.can_access_business_workspace(d.workspace_id,case when d.document_type in ('purchase','purchase_return') then 'purchases.manage' when d.document_type in ('sale','sale_return') then 'sales.manage' else 'inventory.manage' end) and private.can_access_business_workspace_location(d.workspace_id,d.branch_id,erp_business_workspace_document_lines.warehouse_id)));
alter policy workspace_delete on public.erp_business_workspace_document_lines using(exists(select 1 from public.erp_business_workspace_documents d where d.id=erp_business_workspace_document_lines.document_id and d.workspace_id=erp_business_workspace_document_lines.workspace_id and d.status='draft' and private.can_access_business_workspace(d.workspace_id,case when d.document_type in ('purchase','purchase_return') then 'purchases.manage' when d.document_type in ('sale','sale_return') then 'sales.manage' else 'inventory.manage' end) and private.can_access_business_workspace_location(d.workspace_id,d.branch_id,erp_business_workspace_document_lines.warehouse_id)));

alter policy workspace_select on public.erp_business_workspace_stock_movements using(private.can_access_business_workspace(workspace_id,'inventory.read') and private.can_access_business_workspace_location(workspace_id,null,warehouse_id));
alter policy workspace_insert on public.erp_business_workspace_stock_movements with check(private.can_access_business_workspace(workspace_id,'inventory.manage') and private.can_access_business_workspace_location(workspace_id,null,warehouse_id));
alter policy workspace_update on public.erp_business_workspace_stock_movements using(private.can_access_business_workspace(workspace_id,'inventory.manage') and private.can_access_business_workspace_location(workspace_id,null,warehouse_id)) with check(private.can_access_business_workspace(workspace_id,'inventory.manage') and private.can_access_business_workspace_location(workspace_id,null,warehouse_id));
alter policy workspace_delete on public.erp_business_workspace_stock_movements using(private.can_access_business_workspace(workspace_id,'inventory.manage') and private.can_access_business_workspace_location(workspace_id,null,warehouse_id));

alter policy workspace_select on public.erp_business_workspace_stock_openings using(private.can_access_business_workspace(workspace_id,'inventory.read') and private.can_access_business_workspace_location(workspace_id,null,warehouse_id));
alter policy workspace_insert on public.erp_business_workspace_stock_openings with check(private.can_access_business_workspace(workspace_id,'inventory.manage') and private.can_access_business_workspace_location(workspace_id,null,warehouse_id));
alter policy workspace_update on public.erp_business_workspace_stock_openings using(private.can_access_business_workspace(workspace_id,'inventory.manage') and private.can_access_business_workspace_location(workspace_id,null,warehouse_id)) with check(private.can_access_business_workspace(workspace_id,'inventory.manage') and private.can_access_business_workspace_location(workspace_id,null,warehouse_id));
alter policy workspace_delete on public.erp_business_workspace_stock_openings using(private.can_access_business_workspace(workspace_id,'inventory.manage') and private.can_access_business_workspace_location(workspace_id,null,warehouse_id));
