-- Trigger-only functions must not be callable through client RPC.
-- PostgreSQL does not require callers to hold EXECUTE to fire an attached trigger.
REVOKE EXECUTE ON FUNCTION public.erp_assign_customer_geo_code() FROM PUBLIC, anon, authenticated;
REVOKE EXECUTE ON FUNCTION public.erp_assign_geo_hierarchical_code() FROM PUBLIC, anon, authenticated;

-- These three functions intentionally serve the public Silsila ad manifest.
-- All referenced relations are schema-qualified, so an empty search_path is safe.
ALTER FUNCTION public.get_silsila_public_ads(text) SET search_path = '';
ALTER FUNCTION public.get_silsila_public_intro_ad(text) SET search_path = '';
ALTER FUNCTION public.get_silsila_public_popup_ads(text) SET search_path = '';
