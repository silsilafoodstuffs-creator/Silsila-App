alter table public.erp_item_warehouse_settings
  add column if not exists stocktake_unit_id uuid;

update public.erp_item_warehouse_settings
set stocktake_unit_id=coalesce(stocktake_unit_id,sale_unit_id,purchase_unit_id)
where stocktake_unit_id is null;

alter table public.erp_item_warehouse_settings
  alter column stocktake_unit_id set not null;

do $$
begin
 if not exists(select 1 from pg_constraint where conname='erp_item_wh_settings_stocktake_unit_item_fk') then
  alter table public.erp_item_warehouse_settings
   add constraint erp_item_wh_settings_stocktake_unit_item_fk
   foreign key(company_id,item_id,stocktake_unit_id)
   references public.erp_item_units(company_id,item_id,id);
 end if;
end $$;