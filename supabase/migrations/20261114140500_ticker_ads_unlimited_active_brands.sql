-- Reconcile the unlimited ticker slot constraint without replacing the
-- already-deployed RPC definitions. The live database received the stronger
-- save/feed functions under historical versions 20261114134018 and
-- 20261114134125, and 20261114141137 finalizes activity filtering, system
-- brand exclusion, and automatic inclusion of every active brand.
--
-- Keep this migration constraint-only: replaying an older RPC body here would
-- weaken activity validation and remove the automatic all-active-brand feed.
ALTER TABLE public.erp_app_ticker_ads
  DROP CONSTRAINT IF EXISTS erp_app_ticker_ads_slot_no_check;

ALTER TABLE public.erp_app_ticker_ads
  ADD CONSTRAINT erp_app_ticker_ads_slot_no_check
  CHECK (slot_no > 0);
