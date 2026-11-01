create or replace function public.erp_seed_item_warehouse_defaults_after_units()
returns trigger language plpgsql security definer set search_path=''
as $$
begin
 insert into public.erp_item_warehouse_settings
   (company_id,item_id,warehouse_id,purchase_unit_id,sale_unit_id,transfer_unit_id,stocktake_unit_id)
 select i.company_id,i.id,w.id,chosen.id,chosen.id,chosen.id,chosen.id
 from (select distinct company_id,item_id from new_units) inserted
 join public.erp_items i on i.id=inserted.item_id and i.company_id=inserted.company_id and i.is_active=true
 join public.erp_warehouses w on w.company_id=i.company_id and w.is_active=true
 left join lateral (
   select iu.id from public.erp_item_units iu
   where iu.company_id=i.company_id and iu.item_id=i.id and iu.is_active=true and iu.is_selectable=true
   order by iu.conversion_factor desc,iu.is_base_unit asc,iu.created_at asc limit 1
 ) chosen on true
 on conflict(item_id,warehouse_id) do nothing;
 return null;
end $$;
drop trigger if exists trg_erp_seed_item_warehouse_defaults on public.erp_item_units;
create trigger trg_erp_seed_item_warehouse_defaults after insert on public.erp_item_units
referencing new table as new_units for each statement
execute function public.erp_seed_item_warehouse_defaults_after_units();