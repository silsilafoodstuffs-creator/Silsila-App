-- Marketplace directory views expose only approved, curated columns.
-- They must be read-only for API roles; never allow writes through simple views.
revoke all privileges on table public.supplier_directory, public.supplier_public_details, public.customer_directory from anon, authenticated;
grant select on table public.supplier_directory, public.supplier_public_details, public.customer_directory to anon, authenticated;
