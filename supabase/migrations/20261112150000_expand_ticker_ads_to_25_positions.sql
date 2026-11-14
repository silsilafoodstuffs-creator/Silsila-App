-- Expand Silsila's activity-scoped logo ticker from 15 to 25 positions.
-- Keep the save RPC security mode in its dedicated hardening migration.
ALTER TABLE public.erp_app_ticker_ads
  DROP CONSTRAINT IF EXISTS erp_app_ticker_ads_slot_no_check;
ALTER TABLE public.erp_app_ticker_ads
  ADD CONSTRAINT erp_app_ticker_ads_slot_no_check
  CHECK (slot_no BETWEEN 1 AND 25);
