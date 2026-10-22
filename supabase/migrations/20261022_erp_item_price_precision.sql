-- Preserve three decimal places for ERP item purchase and sale prices.
ALTER TABLE public.erp_items
  ALTER COLUMN purchase_price TYPE numeric(14,3) USING purchase_price::numeric(14,3),
  ALTER COLUMN sale_price TYPE numeric(14,3) USING sale_price::numeric(14,3);
