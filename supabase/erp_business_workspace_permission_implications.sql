alter table public.erp_business_workspaces
  add column if not exists platform_company_id uuid references public.erp_companies(id) on delete set null;
create index if not exists erp_business_workspaces_platform_company_idx
  on public.erp_business_workspaces(platform_company_id);
update public.erp_business_workspaces w
set platform_company_id = (
  select cm.company_id
  from public.erp_company_members cm
  join public.profiles p on p.id=cm.user_id
  where p.role='management' and p.account_status='active' and cm.is_active
  order by cm.created_at limit 1
)
where w.platform_company_id is null;

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

create or replace function private.erp_create_business_workspace(
 p_workspace_name text,p_activity_type text default null,p_account_kind text default 'customer'
) returns uuid language plpgsql security definer
set search_path=pg_catalog,public,auth,private
as $$
declare v_id uuid; v_user_id uuid; v_platform_company_id uuid;
begin
 v_user_id := (select auth.uid());
 if v_user_id is null then raise exception 'Authentication required' using errcode='28000'; end if;
 if length(trim(coalesce(p_workspace_name,''))) not between 2 and 160 then raise exception 'Workspace name is invalid' using errcode='22023'; end if;
 if p_account_kind not in ('customer','supplier','other') then raise exception 'Account kind is invalid' using errcode='22023'; end if;
 select cm.company_id into v_platform_company_id from public.erp_company_members cm
 join public.profiles p on p.id=cm.user_id
 where p.role='management' and p.account_status='active' and cm.is_active
 order by cm.created_at limit 1;
 insert into public.erp_business_workspaces(owner_user_id,linked_profile_id,platform_company_id,workspace_name,activity_type,account_kind)
 values(v_user_id,v_user_id,v_platform_company_id,trim(p_workspace_name),nullif(trim(coalesce(p_activity_type,'')),''),p_account_kind)
 returning id into v_id;
 return v_id;
end $$;
revoke all on function private.erp_create_business_workspace(text,text,text) from public,anon;
revoke all on function private.erp_create_business_workspace(text,text,text) from public,anon,authenticated;

create or replace function private.get_workspace_silsila_stock(
 p_workspace_id uuid,p_item_link_id uuid default null
) returns table(
 item_link_id uuid,platform_item_id uuid,item_code text,item_name text,base_unit text,
 workspace_quantity numeric,reorder_level numeric,central_on_hand numeric,central_reserved numeric,central_available numeric
) language plpgsql stable security definer
set search_path=pg_catalog,public,auth,private
as $$
declare v_user uuid:=(select auth.uid()); v_company uuid;
begin
 if v_user is null
  or not private.can_access_business_workspace(p_workspace_id,'inventory.read')
  or not private.can_access_business_workspace(p_workspace_id,'items.read') then
  raise exception 'Insufficient permission to compare workspace stock with Silsila' using errcode='42501';
 end if;
 select platform_company_id into v_company from public.erp_business_workspaces where id=p_workspace_id and is_active;
 if v_company is null then raise exception 'The workspace is not linked to a Silsila company catalog' using errcode='22023'; end if;
 return query
 with links as (
  select l.id,l.platform_item_id,l.reorder_level,ci.item_code,ci.item_name,ci.base_unit
  from public.erp_business_workspace_item_links l
  join public.erp_items ci on ci.id=l.platform_item_id and ci.company_id=v_company and ci.is_active
  where l.workspace_id=p_workspace_id and l.is_enabled and (p_item_link_id is null or l.id=p_item_link_id)
 ), own_stock as (
  select sm.item_link_id,sum(sm.quantity_in-sm.quantity_out)::numeric as qty
  from public.erp_business_workspace_stock_movements sm
  join public.erp_business_workspace_warehouses wh on wh.id=sm.warehouse_id and wh.workspace_id=sm.workspace_id and wh.is_active
  where sm.workspace_id=p_workspace_id
   and private.can_access_business_workspace_location(p_workspace_id,wh.branch_id,wh.id)
  group by sm.item_link_id
 ), central_stock as (
  select m.item_id,coalesce(sum(m.quantity_in-m.quantity_out),0)::numeric as on_hand
  from public.erp_inventory_movements m
  join public.erp_warehouses wh on wh.id=m.warehouse_id and wh.company_id=v_company and wh.is_active
  where m.company_id=v_company group by m.item_id
 ), reserved as (
  select r.item_id,coalesce(sum(r.quantity_base),0)::numeric as qty
  from public.erp_stock_reservations r where r.company_id=v_company and r.status='active' group by r.item_id
 )
 select l.id,l.platform_item_id,l.item_code,l.item_name,l.base_unit,coalesce(o.qty,0),
  coalesce(l.reorder_level,0),coalesce(c.on_hand,0),coalesce(r.qty,0),
  greatest(coalesce(c.on_hand,0)-coalesce(r.qty,0),0)
 from links l left join own_stock o on o.item_link_id=l.id
 left join central_stock c on c.item_id=l.platform_item_id
 left join reserved r on r.item_id=l.platform_item_id order by l.item_name;
end $$;
revoke all on function private.get_workspace_silsila_stock(uuid,uuid) from public,anon;
grant execute on function private.get_workspace_silsila_stock(uuid,uuid) to authenticated;

create or replace function public.erp_get_workspace_silsila_stock(
 p_workspace_id uuid,p_item_link_id uuid default null
) returns table(
 item_link_id uuid,platform_item_id uuid,item_code text,item_name text,base_unit text,
 workspace_quantity numeric,reorder_level numeric,central_on_hand numeric,central_reserved numeric,central_available numeric
) language sql security invoker
set search_path=pg_catalog,public,auth,private
as $$ select * from private.get_workspace_silsila_stock(p_workspace_id,p_item_link_id); $$;
revoke all on function public.erp_get_workspace_silsila_stock(uuid,uuid) from public,anon;
grant execute on function public.erp_get_workspace_silsila_stock(uuid,uuid) to authenticated;

-- Creation is provisioned only by the approved-profile trigger.
revoke execute on function private.erp_create_business_workspace(text,text,text) from public,anon,authenticated;
revoke execute on function public.erp_create_business_workspace(text,text,text) from public,anon,authenticated;
