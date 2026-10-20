-- Keep trigger-only SECURITY DEFINER routines out of the exposed RPC surface.
-- PostgreSQL triggers can continue to invoke these routines after EXECUTE is
-- revoked from API roles; callers must not invoke them directly via PostgREST.
begin;
revoke all on function public.erp_reserve_sales_line() from public, anon, authenticated;
revoke all on function public.erp_sync_sales_reservations_status() from public, anon, authenticated;
commit;
