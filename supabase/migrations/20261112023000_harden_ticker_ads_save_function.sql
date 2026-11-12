-- Keep ticker writes under caller privileges and table RLS.
ALTER FUNCTION public.erp_save_app_ticker_ads(uuid, text, jsonb) SECURITY INVOKER;
