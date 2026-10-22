alter table public.erp_item_categories
  add column if not exists category_name_en text not null default '',
  add column if not exists show_in_app boolean not null default true,
  add column if not exists image_url text;

create index if not exists erp_item_categories_parent_code_idx
  on public.erp_item_categories(company_id, parent_id, category_code);