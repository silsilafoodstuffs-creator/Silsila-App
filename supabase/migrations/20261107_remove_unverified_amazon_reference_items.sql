-- Remove catalog starter rows that were not verified business inventory.
-- These records had zero prices, no posted/operational references and generic
-- Amazon search URLs; keep the category taxonomy but do not present these as stock.
do $$
declare
  v_item_ids uuid[];
begin
  select coalesce(array_agg(i.id), array[]::uuid[])
    into v_item_ids
  from public.erp_items i
  where i.source_name = 'Amazon.eg — تصنيف مرجعي للسوبر ماركت'
    and not exists (select 1 from public.erp_inventory_movements x where x.item_id=i.id)
    and not exists (select 1 from public.erp_sales_lines x where x.item_id=i.id)
    and not exists (select 1 from public.erp_purchase_lines x where x.item_id=i.id)
    and not exists (select 1 from public.erp_stocktake_lines x where x.item_id=i.id)
    and not exists (select 1 from public.erp_stock_adjustment_lines x where x.item_id=i.id)
    and not exists (select 1 from public.erp_stock_reservations x where x.item_id=i.id)
    and not exists (select 1 from public.erp_customer_shortages x where x.item_id=i.id)
    and not exists (select 1 from public.erp_delegate_item_assignments x where x.item_id=i.id)
    and not exists (select 1 from public.erp_price_list_lines x where x.item_id=i.id)
    and not exists (select 1 from public.erp_sales_campaign_items x where x.item_id=i.id)
    and not exists (select 1 from public.erp_manufacturing_bom_lines x where x.item_id=i.id)
    and not exists (select 1 from public.erp_manufacturing_boms x where x.product_id=i.id)
    and not exists (select 1 from public.erp_production_orders x where x.product_id=i.id)
    and not exists (select 1 from public.erp_production_material_movements x where x.item_id=i.id)
    and not exists (select 1 from public.erp_production_variances x where x.item_id=i.id)
    and not exists (select 1 from public.erp_construction_material_request_lines x where x.item_id=i.id)
    and not exists (select 1 from public.erp_business_workspace_item_links x where x.platform_item_id=i.id)
    and not exists (select 1 from public.erp_business_workspace_item_proposals x where x.platform_item_id=i.id);

  delete from public.erp_item_warehouse_settings where item_id = any(v_item_ids);
  delete from public.erp_item_units where item_id = any(v_item_ids);
  delete from public.erp_items where id = any(v_item_ids);
end
$$;
