-- Serialize stock movements for each workspace/warehouse/item key and
-- re-check available quantity inside the transaction to prevent concurrent
-- sales, returns, transfers, or adjustments from creating negative stock.
create or replace function private.guard_business_workspace_stock_movement()
returns trigger
language plpgsql
security definer
set search_path=pg_catalog,public,private
as $$
declare
  v_available numeric;
  v_lock_key bigint;
begin
  if coalesce(new.quantity_in,0)<0 or coalesce(new.quantity_out,0)<0
     or (coalesce(new.quantity_in,0)>0 and coalesce(new.quantity_out,0)>0)
     or coalesce(new.unit_cost,0)<0 then
    raise exception 'Invalid workspace stock movement values' using errcode='22023';
  end if;

  v_lock_key := hashtextextended(
    new.workspace_id::text || ':' || new.warehouse_id::text || ':' || new.item_link_id::text, 0
  );
  perform pg_advisory_xact_lock(v_lock_key);

  if coalesce(new.quantity_out,0)>0 then
    select coalesce(sum(m.quantity_in-m.quantity_out),0)
      into v_available
    from public.erp_business_workspace_stock_movements m
    where m.workspace_id=new.workspace_id
      and m.warehouse_id=new.warehouse_id
      and m.item_link_id=new.item_link_id;

    if v_available < new.quantity_out then
      raise exception 'Insufficient stock after concurrent movements: available %, requested %',
        v_available,new.quantity_out using errcode='23514';
    end if;
  end if;
  return new;
end;
$$;

revoke all on function private.guard_business_workspace_stock_movement() from public,anon,authenticated;
drop trigger if exists erp_biz_ws_stock_nonnegative_guard on public.erp_business_workspace_stock_movements;
create trigger erp_biz_ws_stock_nonnegative_guard
before insert on public.erp_business_workspace_stock_movements
for each row execute function private.guard_business_workspace_stock_movement();
