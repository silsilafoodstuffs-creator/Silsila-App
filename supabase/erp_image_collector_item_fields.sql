-- Add English item names and numeric pricing-area metadata for the ERP image collector.
-- Safe to rerun; does not modify existing item names, prices, inventory, or images.
begin;

alter table public.erp_items
  add column if not exists item_name_en text not null default '',
  add column if not exists pricing_area numeric(14,3) not null default 1
    check (pricing_area >= 0);

comment on column public.erp_items.item_name_en is
  'Optional English item name maintained by ERP master-data forms.';
comment on column public.erp_items.pricing_area is
  'Numeric pricing-area / pricing-basis value maintained by the image collector and item card.';

commit;
