-- Silsila ERP inventory workflow.
-- Apply after erp_schema.sql, erp_operations_schema.sql and erp_security_membership.sql.
-- Stock quantities are ledger-derived. Movements are append-only and written through RPC.

create or replace view public.erp_stock_balances
with (security_invoker = true)
as
select
  m.company_id,
  m.branch_id,
  m.warehouse_id,
  m.item_id,
  coalesce(sum(m.quantity_in - m.quantity_out), 0)::numeric as quantity_on_hand,
  coalesce(sum(case when m.movement_date::date = current_date then m.quantity_in else 0 end), 0)::numeric(18,3) as today_quantity_in,
  coalesce(sum(case when m.movement_date::date = current_date then m.quantity_out else 0 end), 0)::numeric(18,3) as today_quantity_out,
  max(m.movement_date) as last_movement_at,
  coalesce(sum((m.quantity_in - m.quantity_out) * m.unit_cost),0)::numeric(18,2) as inventory_value,
  case
    when coalesce(sum(m.quantity_in - m.quantity_out),0) <= 0 then 0::numeric
    else round(coalesce(sum((m.quantity_in - m.quantity_out) * m.unit_cost),0)
      / sum(m.quantity_in - m.quantity_out), 4)
  end as average_unit_cost
from public.erp_inventory_movements m
where m.movement_date <= now()
group by m.company_id, m.branch_id, m.warehouse_id, m.item_id;


-- Read access for the stock ledger is membership-scoped; writes remain RPC-only.
grant select on public.erp_inventory_movements to authenticated;
drop policy if exists erp_inventory_movements_select_member on public.erp_inventory_movements;
create policy erp_inventory_movements_select_member
on public.erp_inventory_movements
for select to authenticated
using (public.erp_user_can_access_company(company_id));

create or replace function public.erp_record_inventory_movement(
  p_company_id uuid,
  p_warehouse_id uuid,
  p_item_id uuid,
  p_movement_type text,
  p_quantity numeric,
  p_unit_cost numeric default 0,
  p_branch_id uuid default null,
  p_movement_date timestamptz default now(),
  p_reference_type text default null,
  p_reference_id uuid default null,
  p_batch_number text default null,
  p_expiry_date date default null,
  p_notes text default null
)
returns uuid
language plpgsql
security definer
set search_path = public
set row_security = off
as $$
declare
  v_id uuid;
  v_current numeric(18,3);
  v_warehouse_branch uuid;
  v_inventory_value numeric(18,4);
  v_effective_cost numeric(14,4) := p_unit_cost;
  v_in numeric(14,3);
  v_out numeric(14,3);
  v_kind text := lower(trim(p_movement_type));
begin
  if auth.uid() is null then
    raise exception 'يجب تسجيل الدخول أولًا';
  end if;
  if not public.erp_user_has_company_role(
    p_company_id, array['owner','admin','manager','operator','accountant']::text[]
  ) then
    raise exception 'ليست لديك صلاحية تسجيل حركة مخزنية لهذه الشركة';
  end if;
  if p_company_id is null or p_warehouse_id is null or p_item_id is null then
    raise exception 'الشركة والمخزن والصنف حقول إلزامية';
  end if;
  if p_quantity is null or p_quantity <= 0 or p_unit_cost is null or p_unit_cost < 0 then
    raise exception 'الكمية يجب أن تكون أكبر من صفر والتكلفة لا تقل عن صفر';
  end if;
  if p_movement_date is null then
    raise exception 'تاريخ الحركة مطلوب';
  end if;
  if p_movement_date > now() then
    raise exception 'لا يمكن تسجيل حركة مخزنية بتاريخ مستقبلي؛ احتفظ بالمستند مسودة حتى موعده';
  end if;
  if v_kind not in ('opening','purchase_receipt','sales_issue','customer_return','supplier_return','transfer_in','transfer_out','adjustment','waste') then
    raise exception 'نوع الحركة المخزنية غير مدعوم';
  end if;

  select w.branch_id into v_warehouse_branch
  from public.erp_warehouses w
  where w.id = p_warehouse_id and w.company_id = p_company_id and w.is_active;
  if not found then
    raise exception 'المخزن غير نشط أو لا يتبع الشركة المحددة';
  end if;
  if p_branch_id is null then
    p_branch_id := v_warehouse_branch;
  elsif v_warehouse_branch is not null and p_branch_id <> v_warehouse_branch then
    raise exception 'فرع الحركة يجب أن يطابق فرع المخزن';
  end if;
  if not exists (
    select 1 from public.erp_items i
    where i.id = p_item_id and i.company_id = p_company_id and i.is_active
  ) then
    raise exception 'الصنف غير نشط أو لا يتبع الشركة المحددة';
  end if;
  if p_branch_id is not null and not exists (
    select 1 from public.erp_branches b
    where b.id = p_branch_id and b.company_id = p_company_id and b.is_active
  ) then
    raise exception 'الفرع غير نشط أو لا يتبع الشركة المحددة';
  end if;

  -- Serialize updates for this stock bucket so two concurrent issues cannot
  -- both pass the available-stock check against the same old balance.
  perform pg_advisory_xact_lock(hashtextextended(
    p_company_id::text || ':' || p_warehouse_id::text || ':' || p_item_id::text, 0
  ));

  v_in := case when v_kind in ('opening','purchase_receipt','customer_return','transfer_in') then p_quantity else 0 end;
  v_out := case when v_kind in ('sales_issue','supplier_return','transfer_out','waste') then p_quantity else 0 end;

  if v_kind = 'adjustment' then
    raise exception 'التسوية تتطلب تحديد اتجاه الزيادة أو النقص؛ استخدم حركة واردة أو منصرفة مناسبة';
  end if;

  if v_out > 0 and exists (
    select 1 from public.erp_inventory_movements m
    where m.company_id = p_company_id and m.warehouse_id = p_warehouse_id
      and m.item_id = p_item_id and m.movement_date > p_movement_date
  ) then
    raise exception 'لا يمكن تسجيل صرف بتاريخ أقدم من حركات لاحقة للصنف؛ راجع التسلسل الزمني أولًا';
  end if;

  if v_out > 0 then
    select coalesce(sum(m.quantity_in - m.quantity_out), 0)
      into v_current
    from public.erp_inventory_movements m
    where m.company_id = p_company_id
      and m.warehouse_id = p_warehouse_id
      and m.item_id = p_item_id
      and m.movement_date <= p_movement_date;
    if v_current < p_quantity then
      raise exception 'الرصيد غير كافٍ. الرصيد الحالي % والكمية المطلوبة %', v_current, p_quantity;
    end if;
    select coalesce(sum(m.quantity_in * m.unit_cost) - sum(m.quantity_out * m.unit_cost),0)
      into v_inventory_value
    from public.erp_inventory_movements m
    where m.company_id = p_company_id and m.warehouse_id = p_warehouse_id
      and m.item_id = p_item_id and m.movement_date <= p_movement_date;
    if v_current > 0 then
      v_effective_cost := greatest(v_inventory_value / v_current, 0);
    end if;
  end if;

  if v_kind = 'customer_return' then
    select coalesce(sum(m.quantity_in - m.quantity_out),0),
      coalesce(sum(m.quantity_in * m.unit_cost) - sum(m.quantity_out * m.unit_cost),0)
      into v_current, v_inventory_value
    from public.erp_inventory_movements m
    where m.company_id = p_company_id and m.warehouse_id = p_warehouse_id
      and m.item_id = p_item_id and m.movement_date <= p_movement_date;
    if v_current > 0 then
      v_effective_cost := greatest(v_inventory_value / v_current, 0);
    else
      select i.purchase_price into v_effective_cost from public.erp_items i
      where i.id = p_item_id and i.company_id = p_company_id;
    end if;
  end if;

  insert into public.erp_inventory_movements(
    company_id, branch_id, warehouse_id, item_id, movement_date,
    movement_type, quantity_in, quantity_out, unit_cost, reference_type,
    reference_id, batch_number, expiry_date, notes, created_by
  ) values (
    p_company_id, p_branch_id, p_warehouse_id, p_item_id, p_movement_date,
    v_kind, v_in, v_out, v_effective_cost, nullif(trim(p_reference_type), ''),
    p_reference_id, nullif(trim(p_batch_number), ''), p_expiry_date,
    nullif(trim(p_notes), ''), auth.uid()
  ) returning id into v_id;

  return v_id;
end;
$$;

revoke all on function public.erp_record_inventory_movement(
  uuid,uuid,uuid,text,numeric,numeric,uuid,timestamptz,text,uuid,text,date,text
) from public, anon;
grant execute on function public.erp_record_inventory_movement(
  uuid,uuid,uuid,text,numeric,numeric,uuid,timestamptz,text,uuid,text,date,text
) to authenticated;

grant select on public.erp_stock_balances to authenticated;

comment on view public.erp_stock_balances is
  'Current quantities derived from the append-only inventory movement ledger.';
comment on function public.erp_record_inventory_movement(
  uuid,uuid,uuid,text,numeric,numeric,uuid,timestamptz,text,uuid,text,date,text
) is
  'Authorized append-only stock movement; validates company ownership and serializes stock-out checks.';


create or replace function public.erp_transfer_inventory_between_warehouses(
  p_company_id uuid,
  p_source_warehouse_id uuid,
  p_target_warehouse_id uuid,
  p_item_id uuid,
  p_quantity numeric,
  p_unit_cost numeric default 0,
  p_transfer_date timestamptz default now(),
  p_batch_number text default null,
  p_expiry_date date default null,
  p_notes text default null
)
returns uuid
language plpgsql
security definer
set search_path = public
set row_security = off
as $$
declare
  v_transfer_id uuid := gen_random_uuid();
  v_source_balance numeric(18,3);
  v_source_value numeric(18,4);
  v_effective_cost numeric(14,4) := p_unit_cost;
  v_source_branch uuid;
  v_target_branch uuid;
begin
  if auth.uid() is null then raise exception 'يجب تسجيل الدخول أولًا'; end if;
  if not public.erp_user_has_company_role(
    p_company_id, array['owner','admin','manager','operator','accountant']::text[]
  ) then raise exception 'ليست لديك صلاحية تحويل المخزون'; end if;
  if p_source_warehouse_id is null or p_target_warehouse_id is null
     or p_source_warehouse_id = p_target_warehouse_id then
    raise exception 'اختر مخزنين مختلفين للتحويل'; end if;
  if p_item_id is null or p_quantity is null or p_quantity <= 0
     or p_unit_cost is null or p_unit_cost < 0 or p_transfer_date is null then
    raise exception 'الصنف والتاريخ والكمية الموجبة والتكلفة الصحيحة مطلوبة'; end if;
  if p_transfer_date > now() then raise exception 'لا يمكن تحويل مخزون بتاريخ مستقبلي'; end if;

  if not exists (select 1 from public.erp_items i
    where i.id = p_item_id and i.company_id = p_company_id and i.is_active) then
    raise exception 'الصنف غير نشط أو لا يتبع الشركة'; end if;

  select branch_id into v_source_branch from public.erp_warehouses
  where id = p_source_warehouse_id and company_id = p_company_id and is_active;
  if not found then raise exception 'مخزن الصرف غير نشط أو لا يتبع الشركة'; end if;
  select branch_id into v_target_branch from public.erp_warehouses
  where id = p_target_warehouse_id and company_id = p_company_id and is_active;
  if not found then raise exception 'مخزن الاستلام غير نشط أو لا يتبع الشركة'; end if;

  perform pg_advisory_xact_lock(hashtextextended(
    p_company_id::text || ':' || least(p_source_warehouse_id::text, p_target_warehouse_id::text) || ':' || p_item_id::text, 0
  ));
  perform pg_advisory_xact_lock(hashtextextended(
    p_company_id::text || ':' || greatest(p_source_warehouse_id::text, p_target_warehouse_id::text) || ':' || p_item_id::text, 0
  ));

  if exists (
    select 1 from public.erp_inventory_movements m
    where m.company_id = p_company_id and m.warehouse_id = p_source_warehouse_id
      and m.item_id = p_item_id and m.movement_date > p_transfer_date
  ) then
    raise exception 'لا يمكن تحويل مخزون بتاريخ أقدم من حركات لاحقة للصنف في مخزن المصدر';
  end if;

  select coalesce(sum(m.quantity_in - m.quantity_out),0)
    into v_source_balance
  from public.erp_inventory_movements m
  where m.company_id = p_company_id
    and m.warehouse_id = p_source_warehouse_id
    and m.item_id = p_item_id
    and m.movement_date <= p_transfer_date;
  if v_source_balance < p_quantity then
    raise exception 'رصيد مخزن الصرف غير كافٍ. المتاح % والمطلوب %', v_source_balance, p_quantity;
  end if;
  select coalesce(sum(m.quantity_in * m.unit_cost) - sum(m.quantity_out * m.unit_cost),0)
    into v_source_value
  from public.erp_inventory_movements m
  where m.company_id = p_company_id and m.warehouse_id = p_source_warehouse_id
    and m.item_id = p_item_id and m.movement_date <= p_transfer_date;
  if v_source_balance > 0 then
    v_effective_cost := greatest(v_source_value / v_source_balance, 0);
  end if;

  insert into public.erp_inventory_movements(
    company_id, branch_id, warehouse_id, item_id, movement_date, movement_type,
    quantity_in, quantity_out, unit_cost, reference_type, reference_id,
    batch_number, expiry_date, notes, created_by
  ) values (
    p_company_id, v_source_branch, p_source_warehouse_id, p_item_id, p_transfer_date,
    'transfer_out', 0, p_quantity, v_effective_cost, 'warehouse_transfer', v_transfer_id,
    nullif(trim(p_batch_number), ''), p_expiry_date, nullif(trim(p_notes), ''), auth.uid()
  );

  insert into public.erp_inventory_movements(
    company_id, branch_id, warehouse_id, item_id, movement_date, movement_type,
    quantity_in, quantity_out, unit_cost, reference_type, reference_id,
    batch_number, expiry_date, notes, created_by
  ) values (
    p_company_id, v_target_branch, p_target_warehouse_id, p_item_id, p_transfer_date,
    'transfer_in', p_quantity, 0, v_effective_cost, 'warehouse_transfer', v_transfer_id,
    nullif(trim(p_batch_number), ''), p_expiry_date, nullif(trim(p_notes), ''), auth.uid()
  );

  return v_transfer_id;
end;
$$;

revoke all on function public.erp_transfer_inventory_between_warehouses(
  uuid,uuid,uuid,uuid,numeric,numeric,timestamptz,text,date,text
) from public, anon;
grant execute on function public.erp_transfer_inventory_between_warehouses(
  uuid,uuid,uuid,uuid,numeric,numeric,timestamptz,text,date,text
) to authenticated;

comment on function public.erp_transfer_inventory_between_warehouses(
  uuid,uuid,uuid,uuid,numeric,numeric,timestamptz,text,date,text
) is 'Creates matched transfer-out and transfer-in stock ledger records atomically.';
