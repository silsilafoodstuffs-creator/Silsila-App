-- Enforce company/item/warehouse/unit ownership consistency for per-warehouse item defaults.
create unique index if not exists ux_erp_items_company_id_id on public.erp_items(company_id,id);
create unique index if not exists ux_erp_warehouses_company_id_id on public.erp_warehouses(company_id,id);
create unique index if not exists ux_erp_item_units_company_item_id on public.erp_item_units(company_id,item_id,id);

do $$
begin
  if not exists(select 1 from pg_constraint where conname='erp_item_wh_settings_item_company_fk') then
    alter table public.erp_item_warehouse_settings
      add constraint erp_item_wh_settings_item_company_fk
      foreign key(company_id,item_id) references public.erp_items(company_id,id);
  end if;
  if not exists(select 1 from pg_constraint where conname='erp_item_wh_settings_warehouse_company_fk') then
    alter table public.erp_item_warehouse_settings
      add constraint erp_item_wh_settings_warehouse_company_fk
      foreign key(company_id,warehouse_id) references public.erp_warehouses(company_id,id);
  end if;
  if not exists(select 1 from pg_constraint where conname='erp_item_wh_settings_purchase_unit_item_fk') then
    alter table public.erp_item_warehouse_settings
      add constraint erp_item_wh_settings_purchase_unit_item_fk
      foreign key(company_id,item_id,purchase_unit_id) references public.erp_item_units(company_id,item_id,id);
  end if;
  if not exists(select 1 from pg_constraint where conname='erp_item_wh_settings_sale_unit_item_fk') then
    alter table public.erp_item_warehouse_settings
      add constraint erp_item_wh_settings_sale_unit_item_fk
      foreign key(company_id,item_id,sale_unit_id) references public.erp_item_units(company_id,item_id,id);
  end if;
  if not exists(select 1 from pg_constraint where conname='erp_item_wh_settings_transfer_unit_item_fk') then
    alter table public.erp_item_warehouse_settings
      add constraint erp_item_wh_settings_transfer_unit_item_fk
      foreign key(company_id,item_id,transfer_unit_id) references public.erp_item_units(company_id,item_id,id);
  end if;
end $$;
