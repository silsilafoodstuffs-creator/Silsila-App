create unique index if not exists erp_item_units_one_selectable_level
on public.erp_item_units(company_id, item_id, unit_level)
where is_active = true and is_selectable = true and is_implicit = false and unit_level is not null;

create or replace function public.erp_validate_item_warehouse_unit_selection()
returns trigger
language plpgsql
security invoker
set search_path = public, pg_temp
as $function$
declare
  v_unit_id uuid;
begin
  foreach v_unit_id in array array[
    new.purchase_unit_id, new.sale_unit_id, new.transfer_unit_id, new.stocktake_unit_id
  ] loop
    if v_unit_id is not null and not exists (
      select 1 from public.erp_item_units u
      where u.id = v_unit_id and u.company_id = new.company_id
        and u.item_id = new.item_id and u.is_active = true
        and u.is_selectable = true and u.is_implicit = false
    ) then
      raise exception 'Selected warehouse unit must be active, selectable, explicit, and belong to the same item and company'
        using errcode = '23514';
    end if;
  end loop;
  return new;
end;
$function$;

drop trigger if exists trg_erp_validate_item_warehouse_unit_selection
on public.erp_item_warehouse_settings;

create trigger trg_erp_validate_item_warehouse_unit_selection
before insert or update of purchase_unit_id, sale_unit_id, transfer_unit_id, stocktake_unit_id, item_id, company_id
on public.erp_item_warehouse_settings
for each row execute function public.erp_validate_item_warehouse_unit_selection();

create or replace function public.erp_prevent_disabling_assigned_item_unit()
returns trigger
language plpgsql
security invoker
set search_path = public, pg_temp
as $function$
begin
  if old.is_active = true
     and (new.is_active = false or new.is_selectable = false or new.is_implicit = true)
     and exists (
       select 1 from public.erp_item_warehouse_settings s
       where s.company_id = old.company_id and s.item_id = old.item_id
         and old.id in (s.purchase_unit_id, s.sale_unit_id, s.transfer_unit_id, s.stocktake_unit_id)
     ) then
    raise exception 'Cannot disable or hide a unit currently selected in warehouse settings; assign replacement units first'
      using errcode = '23514';
  end if;
  return new;
end;
$function$;

drop trigger if exists trg_erp_prevent_disabling_assigned_item_unit
on public.erp_item_units;

create trigger trg_erp_prevent_disabling_assigned_item_unit
before update of is_active, is_selectable, is_implicit
on public.erp_item_units
for each row execute function public.erp_prevent_disabling_assigned_item_unit();
