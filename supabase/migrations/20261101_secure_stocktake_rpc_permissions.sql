revoke all on function public.erp_create_physical_stocktake(uuid,uuid,text,text,text) from public, anon;
revoke all on function public.erp_post_physical_stocktake(uuid,text,uuid) from public, anon;
revoke all on function public.erp_save_physical_stocktake_counts(uuid,jsonb) from public, anon;
revoke all on function public.erp_seed_item_warehouse_defaults_after_units() from public, anon, authenticated;

grant execute on function public.erp_create_physical_stocktake(uuid,uuid,text,text,text) to authenticated;
grant execute on function public.erp_post_physical_stocktake(uuid,text,uuid) to authenticated;
grant execute on function public.erp_save_physical_stocktake_counts(uuid,jsonb) to authenticated;