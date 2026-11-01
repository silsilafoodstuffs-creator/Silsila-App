create or replace function public.erp_seed_item_warehouse_defaults_after_warehouse()
returns trigger language plpgsql security definer set search_path='' as $$
begin
 if new.is_active=true then
   insert into public.erp_item_warehouse_settings
     (company_id,item_id,warehouse_id,purchase_unit_id,sale_unit_id,transfer_unit_id,stocktake_unit_id)
   select i.company_id,i.id,new.id,chosen.id,chosen.id,chosen.id,chosen.id
   from public.erp_items i
   left join lateral (
     select iu.id from public.erp_item_units iu
     where iu.company_id=i.company_id and iu.item_id=i.id
       and iu.is_active=true and iu.is_selectable=true
     order by iu.conversion_factor desc,iu.is_base_unit asc,iu.created_at asc limit 1
   ) chosen on true
   where i.company_id=new.company_id and i.is_active=true
   on conflict(item_id,warehouse_id) do nothing;
 end if;
 return new;
end $$;

drop trigger if exists trg_erp_seed_warehouse_item_defaults on public.erp_warehouses;
create trigger trg_erp_seed_warehouse_item_defaults
after insert or update of is_active on public.erp_warehouses
for each row execute function public.erp_seed_item_warehouse_defaults_after_warehouse();