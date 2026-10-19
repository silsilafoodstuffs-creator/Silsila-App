-- Hardening for the shared ERP timestamp trigger.
-- This trigger only calls the built-in now() function and assigns a field on NEW.
-- Pin search_path to pg_catalog to prevent object shadowing.
begin;
alter function public.erp_set_updated_at() set search_path = pg_catalog;
commit;
