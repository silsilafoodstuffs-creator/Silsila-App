-- Preserve the existing public ticker sequence when moving ordering to brand master.
UPDATE public.erp_brands AS brand
SET display_order = ticker.slot_no
FROM public.erp_app_ticker_ads AS ticker
JOIN public.erp_managed_apps AS app
  ON app.id = ticker.app_id
 AND app.company_id = ticker.company_id
 AND app.app_key = 'silsila'
 AND app.status = 'active'
WHERE ticker.brand_id = brand.id
  AND ticker.company_id = brand.company_id;
