create index if not exists idx_erp_ws_counterparties_created_by
  on public.erp_business_workspace_counterparties(created_by);
create index if not exists idx_profiles_phone_normalized_preview
  on public.profiles ((regexp_replace(coalesce(phone,''),'[^0-9+]','','g')))
  where phone is not null;
create index if not exists idx_profiles_whatsapp_normalized_preview
  on public.profiles ((regexp_replace(coalesce(whatsapp_phone,''),'[^0-9+]','','g')))
  where whatsapp_phone is not null;
