begin;

-- This is an internal BEFORE INSERT trigger function, not a client RPC.
-- Trigger execution continues through the trigger binding; direct RPC access
-- is intentionally denied to PUBLIC, anon, and authenticated callers.
revoke all on function public.erp_assign_brand_group_code() from public, anon, authenticated;

commit;
