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
  coalesce(sum(m.quantity_in - m.quantity_out), 0)::numeric(18,3) as quantity_on_hand,
  coalesce(sum(case when m.movement_date::date = current_date then m.quantity_in else 0 end), 0)::numeric(18,3) as today_quantity_in,
  coalesce(sum(case when m.movement_date::date = current_date then m.quantity_out else 0 end), 0)::numeric(18,3) as today_quantity_out,
  max(m.movement_date) as last_movement_at
from public.erp_inventory_movements m
group by m.company_id, m.branch_id, m.warehouse_id, m.item_id;

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
  if v_kind not in ('opening','purchase_receipt','sales_issue','customer_return','supplier_return','transfer_in','transfer_out','adjustment','waste') then
    raise exception 'نوع الحركة المخزنية غير مدعوم';
  end if;

  if not exists (
    select 1 from public.erp_warehouses w
    where w.id = p_warehouse_id and w.company_id = p_company_id and w.is_active
  ) then
    raise exception 'المخزن غير نشط أو لا يتبع الشركة المحددة';
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

  if v_out > 0 then
    select coalesce(sum(m.quantity_in - m.quantity_out), 0)
      into v_current
    from public.erp_inventory_movements m
    where m.company_id = p_company_id
      and m.warehouse_id = p_warehouse_id
      and m.item_id = p_item_id;
    if v_current < p_quantity then
      raise exception 'الرصيد غير كافٍ. الرصيد الحالي % والكمية المطلوبة %', v_current, p_quantity;
    end if;
  end if;

  insert into public.erp_inventory_movements(
    company_id, branch_id, warehouse_id, item_id, movement_date,
    movement_type, quantity_in, quantity_out, unit_cost, reference_type,
    reference_id, batch_number, expiry_date, notes, created_by
  ) values (
    p_company_id, p_branch_id, p_warehouse_id, p_item_id, p_movement_date,
    v_kind, v_in, v_out, p_unit_cost, nullif(trim(p_reference_type), ''),
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
