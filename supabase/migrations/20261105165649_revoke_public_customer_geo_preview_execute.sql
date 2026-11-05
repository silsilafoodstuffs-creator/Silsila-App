revoke all on function public.erp_preview_next_customer_geo_code(uuid,uuid) from public;
revoke all on function public.erp_preview_next_customer_geo_code(uuid,uuid) from anon;
grant execute on function public.erp_preview_next_customer_geo_code(uuid,uuid) to authenticated;
