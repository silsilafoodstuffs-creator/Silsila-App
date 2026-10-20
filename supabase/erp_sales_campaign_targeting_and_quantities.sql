-- Extend ERP sales campaigns with explicit targeting and finite offer quantities.
alter table public.erp_sales_campaigns
  add column if not exists target_customer_ids jsonb not null default '[]'::jsonb,
  add column if not exists target_warehouse_ids jsonb not null default '[]'::jsonb,
  add column if not exists target_branch_ids jsonb not null default '[]'::jsonb,
  add column if not exists target_centers jsonb not null default '[]'::jsonb,
  add column if not exists target_customer_types jsonb not null default '[]'::jsonb,
  add column if not exists target_governorates jsonb not null default '[]'::jsonb,
  add column if not exists target_districts jsonb not null default '[]'::jsonb,
  add column if not exists target_areas jsonb not null default '[]'::jsonb;

alter table public.erp_sales_campaign_items
  add column if not exists offer_quantity numeric(18,4),
  add column if not exists remaining_quantity numeric(18,4),
  add column if not exists discount_value numeric(18,4) not null default 0,
  add column if not exists discount_kind text not null default 'none'
    check (discount_kind in ('none','amount','percent','special_price','buy_get','clearance'));

alter table public.erp_sales_campaigns
  drop constraint if exists erp_sales_campaign_target_json_arrays_check;
alter table public.erp_sales_campaigns
  add constraint erp_sales_campaign_target_json_arrays_check check (
    jsonb_typeof(target_customer_ids) = 'array'
    and jsonb_typeof(target_warehouse_ids) = 'array'
    and jsonb_typeof(target_branch_ids) = 'array'
    and jsonb_typeof(target_centers) = 'array'
    and jsonb_typeof(target_customer_types) = 'array'
    and jsonb_typeof(target_governorates) = 'array'
    and jsonb_typeof(target_districts) = 'array'
    and jsonb_typeof(target_areas) = 'array'
  );

alter table public.erp_sales_campaign_items
  drop constraint if exists erp_sales_campaign_item_remaining_check;
alter table public.erp_sales_campaign_items
  add constraint erp_sales_campaign_item_remaining_check check (
    (offer_quantity is null or offer_quantity >= 0)
    and (remaining_quantity is null or remaining_quantity >= 0)
    and (offer_quantity is null or remaining_quantity is null or remaining_quantity <= offer_quantity)
    and discount_value >= 0
  );

create index if not exists erp_sales_campaign_target_customer_idx
  on public.erp_sales_campaigns(company_id, owner_party_id, is_active);
