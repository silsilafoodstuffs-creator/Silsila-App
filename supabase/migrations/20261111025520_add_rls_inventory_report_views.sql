create or replace view public.erp_v_inventory_item_stock_status
with (security_invoker = true)
as
with active_items as (
  select i.id as item_id, i.company_id, i.item_code, i.item_name, i.base_unit,
         coalesce(i.reorder_level, 0)::numeric as reorder_level
  from public.erp_items i
  where i.is_active = true
    and coalesce(i.is_demo_data, false) = false
),
active_warehouses as (
  select w.id as warehouse_id, w.company_id, w.branch_id,
         w.warehouse_code, w.warehouse_name
  from public.erp_warehouses w
  where w.is_active = true
),
reservations as (
  select r.company_id, r.warehouse_id, r.item_id,
         sum(r.quantity_base)::numeric as reserved_quantity
  from public.erp_stock_reservations r
  where r.status = 'active'
  group by r.company_id, r.warehouse_id, r.item_id
)
select
  i.company_id,
  w.branch_id,
  w.warehouse_id,
  w.warehouse_code,
  w.warehouse_name,
  i.item_id,
  i.item_code,
  i.item_name,
  i.base_unit,
  coalesce(b.quantity_on_hand, 0)::numeric as quantity_on_hand,
  coalesce(r.reserved_quantity, 0)::numeric as reserved_quantity,
  (coalesce(b.quantity_on_hand, 0) - coalesce(r.reserved_quantity, 0))::numeric as available_quantity,
  i.reorder_level,
  greatest(i.reorder_level - (coalesce(b.quantity_on_hand, 0) - coalesce(r.reserved_quantity, 0)), 0)::numeric as reorder_shortage_quantity,
  b.last_movement_at,
  case when b.last_movement_at is null then null
       else greatest(current_date - b.last_movement_at::date, 0) end as days_since_last_movement,
  coalesce(b.inventory_value, 0)::numeric as inventory_value,
  coalesce(b.average_unit_cost, 0)::numeric as average_unit_cost
from active_items i
join active_warehouses w on w.company_id = i.company_id
left join public.erp_stock_balances b
  on b.company_id = i.company_id
 and b.warehouse_id = w.warehouse_id
 and b.item_id = i.item_id
left join reservations r
  on r.company_id = i.company_id
 and r.warehouse_id = w.warehouse_id
 and r.item_id = i.item_id;

create or replace view public.erp_v_inventory_low_stock_items
with (security_invoker = true)
as
select *
from public.erp_v_inventory_item_stock_status
where reorder_level > 0
  and available_quantity <= reorder_level;

create or replace view public.erp_v_inventory_slow_moving_items
with (security_invoker = true)
as
select *
from public.erp_v_inventory_item_stock_status
where quantity_on_hand > 0
  and last_movement_at is not null
  and last_movement_at < now() - interval '90 days';

revoke all on public.erp_v_inventory_item_stock_status from public, anon;
revoke all on public.erp_v_inventory_low_stock_items from public, anon;
revoke all on public.erp_v_inventory_slow_moving_items from public, anon;
grant select on public.erp_v_inventory_item_stock_status to authenticated;
grant select on public.erp_v_inventory_low_stock_items to authenticated;
grant select on public.erp_v_inventory_slow_moving_items to authenticated;
