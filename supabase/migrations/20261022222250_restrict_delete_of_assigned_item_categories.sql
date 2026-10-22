-- Prevent accidental orphaning of catalog items when a category is deleted.
alter table public.erp_items drop constraint if exists erp_items_category_id_fkey;
alter table public.erp_items add constraint erp_items_category_id_fkey
  foreign key (category_id) references public.erp_item_categories(id) on delete restrict;
