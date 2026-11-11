-- Enforce user branch/warehouse scope at the database boundary and save assignments atomically.
-- Legacy owner/admin access remains unrestricted; non-admin ERP users must have explicit assignments.
create or replace function public.erp_user_can_access_branch_scope(
  p_company_id uuid,
  p_branch_id uuid
) returns boolean
language plpgsql stable security definer
set search_path = ''
set row_security = off
as $$
declare v_erp_user_id uuid;
begin
  if auth.uid() is null or p_company_id is null or p_branch_id is null then return false; end if;
  if public.erp_user_has_company_role(p_company_id, array['owner','admin']::text[]) then return true; end if;
  select u.id into v_erp_user_id
  from public.erp_users u
  where u.company_id = p_company_id and u.auth_user_id = auth.uid() and u.is_active = true
  limit 1;
  if v_erp_user_id is null then return false; end if;
  return exists (
    select 1 from public.erp_user_branch_warehouse_access a
    where a.company_id = p_company_id and a.user_id = v_erp_user_id
      and a.branch_id = p_branch_id and a.is_allowed = true
  );
end;
$$;

create or replace function public.erp_user_can_access_warehouse_scope(
  p_company_id uuid,
  p_branch_id uuid,
  p_warehouse_id uuid
) returns boolean
language plpgsql stable security definer
set search_path = ''
set row_security = off
as $$
declare v_erp_user_id uuid;
begin
  if auth.uid() is null or p_company_id is null or p_branch_id is null or p_warehouse_id is null then return false; end if;
  if public.erp_user_has_company_role(p_company_id, array['owner','admin']::text[]) then return true; end if;
  select u.id into v_erp_user_id
  from public.erp_users u
  where u.company_id = p_company_id and u.auth_user_id = auth.uid() and u.is_active = true
  limit 1;
  if v_erp_user_id is null then return false; end if;
  return exists (
    select 1
    from public.erp_user_branch_warehouse_access a
    join public.erp_warehouses w
      on w.id = a.warehouse_id and w.company_id = a.company_id
     and w.branch_id = a.branch_id and w.is_active = true
    where a.company_id = p_company_id and a.user_id = v_erp_user_id
      and a.branch_id = p_branch_id and a.warehouse_id = p_warehouse_id
      and a.is_allowed = true
  );
end;
$$;

revoke all on function public.erp_user_can_access_branch_scope(uuid,uuid) from public, anon;
revoke all on function public.erp_user_can_access_warehouse_scope(uuid,uuid,uuid) from public, anon;
grant execute on function public.erp_user_can_access_branch_scope(uuid,uuid) to authenticated;
grant execute on function public.erp_user_can_access_warehouse_scope(uuid,uuid,uuid) to authenticated;

create or replace function public.erp_replace_user_branch_warehouse_access(
  p_company_id uuid,
  p_user_id uuid,
  p_assignments jsonb
) returns integer
language plpgsql
security definer
set search_path = ''
set row_security = off
as $$
declare
  v_target_user uuid;
  v_count integer;
  v_defaults integer;
begin
  if auth.uid() is null
     or not public.erp_user_has_company_role(p_company_id, array['owner','admin','manager']::text[]) then
    raise exception 'ليست لديك صلاحية إدارة نطاقات الفروع والمخازن' using errcode = '42501';
  end if;
  select u.id into v_target_user
  from public.erp_users u
  where u.id = p_user_id and u.company_id = p_company_id and u.is_active = true
  for update;
  if v_target_user is null then raise exception 'المستخدم المستهدف غير نشط أو لا يتبع الشركة'; end if;
  if p_assignments is null or jsonb_typeof(p_assignments) <> 'array'
     or jsonb_array_length(p_assignments) = 0 then
    raise exception 'يجب اختيار مخزن واحد على الأقل قبل حفظ نطاق المستخدم';
  end if;
  if jsonb_array_length(p_assignments) > 1000 then
    raise exception 'عدد تخصيصات المخازن يتجاوز الحد المسموح';
  end if;
  select count(*) filter (where x.is_default)
    into v_defaults
  from jsonb_to_recordset(p_assignments) as x(branch_id uuid, warehouse_id uuid, is_default boolean);
  if v_defaults > 1 then raise exception 'يمكن تحديد مخزن افتراضي واحد فقط'; end if;
  if exists (
    select 1
    from jsonb_to_recordset(p_assignments) as x(branch_id uuid, warehouse_id uuid, is_default boolean)
    left join public.erp_warehouses w
      on w.id = x.warehouse_id and w.company_id = p_company_id
     and w.branch_id = x.branch_id and w.is_active = true
    left join public.erp_branches b
      on b.id = x.branch_id and b.company_id = p_company_id and b.is_active = true
    where x.branch_id is null or x.warehouse_id is null or w.id is null or b.id is null
  ) then
    raise exception 'يوجد فرع أو مخزن غير نشط أو لا يتبع الشركة أو لا يتبع الفرع المحدد';
  end if;
  if exists (
    select 1
    from jsonb_to_recordset(p_assignments) as x(branch_id uuid, warehouse_id uuid, is_default boolean)
    group by x.branch_id, x.warehouse_id having count(*) > 1
  ) then raise exception 'يوجد مخزن مكرر ضمن التخصيصات'; end if;

  delete from public.erp_user_branch_warehouse_access
  where company_id = p_company_id and user_id = v_target_user;

  insert into public.erp_user_branch_warehouse_access(
    company_id, user_id, branch_id, warehouse_id, is_allowed, is_default
  )
  select p_company_id, v_target_user, x.branch_id, x.warehouse_id, true, coalesce(x.is_default,false)
  from jsonb_to_recordset(p_assignments) as x(branch_id uuid, warehouse_id uuid, is_default boolean);

  get diagnostics v_count = row_count;
  return v_count;
end;
$$;

revoke all on function public.erp_replace_user_branch_warehouse_access(uuid,uuid,jsonb) from public, anon;
grant execute on function public.erp_replace_user_branch_warehouse_access(uuid,uuid,jsonb) to authenticated;

-- Managers may administer the scope picker; ordinary users only see assigned branches/warehouses.
drop policy if exists erp_branches_select_member on public.erp_branches;
create policy erp_branches_select_member on public.erp_branches
for select to authenticated
using (
  public.erp_user_has_company_role(company_id, array['owner','admin','manager']::text[])
  or public.erp_user_can_access_branch_scope(company_id, id)
);

drop policy if exists erp_warehouses_select_member on public.erp_warehouses;
create policy erp_warehouses_select_member on public.erp_warehouses
for select to authenticated
using (
  public.erp_user_has_company_role(company_id, array['owner','admin','manager']::text[])
  or public.erp_user_can_access_warehouse_scope(company_id, branch_id, id)
);

create or replace function public.erp_enforce_inventory_movement_user_scope()
returns trigger
language plpgsql
security definer
set search_path = ''
set row_security = off
as $$
begin
  -- Trusted server-side jobs may have no end-user JWT; authenticated requests must pass scope.
  if auth.uid() is null then return new; end if;
  if not public.erp_user_can_access_warehouse_scope(new.company_id, new.branch_id, new.warehouse_id) then
    raise exception 'ليس لديك تصريح على فرع ومخزن هذه الحركة' using errcode = '42501';
  end if;
  return new;
end;
$$;

drop trigger if exists trg_erp_inventory_movement_user_scope on public.erp_inventory_movements;
create trigger trg_erp_inventory_movement_user_scope
before insert on public.erp_inventory_movements
for each row execute function public.erp_enforce_inventory_movement_user_scope();
