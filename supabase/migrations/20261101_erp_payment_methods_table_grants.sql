-- Least-privilege grants for the payment-methods master table.
-- RLS remains the row-level authorization boundary for authenticated company members.
revoke all privileges on table public.erp_payment_methods from anon;
revoke all privileges on table public.erp_payment_methods from authenticated;
grant select, insert, update on table public.erp_payment_methods to authenticated;
