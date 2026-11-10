-- Cover the composite company/brand foreign key for item lookups and referential checks.
CREATE INDEX IF NOT EXISTS erp_items_company_brand_idx
  ON public.erp_items(company_id, brand_id);