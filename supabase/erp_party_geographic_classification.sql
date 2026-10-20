alter table public.erp_parties
  add column if not exists customer_type text,
  add column if not exists center text,
  add column if not exists area text;
