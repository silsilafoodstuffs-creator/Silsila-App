-- Trigger-only SECURITY DEFINER functions must not be exposed as callable RPCs.
-- Trigger execution continues to work; these functions have no client-facing API contract.
revoke execute on function public.erp_consume_campaign_quantities_on_post() from public, anon, authenticated;
revoke execute on function public.erp_seed_default_user_types() from public, anon, authenticated;
revoke execute on function public.erp_sync_company_member_to_erp_user() from public, anon, authenticated;
revoke execute on function public.erp_validate_campaign_sales_line() from public, anon, authenticated;
revoke execute on function public.erp_validate_customer_shortage_sales_line() from public, anon, authenticated;
