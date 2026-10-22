-- Read-only quality audit for Silsila catalog images.
-- Run in Supabase SQL Editor after each image-import batch.
-- This script never changes catalog data.

select
  'categories' as table_name,
  count(*) as total_rows,
  count(*) filter (where image_data is not null) as rows_with_binary_image,
  count(*) filter (where image_data is not null and octet_length(image_data) < 5000) as images_under_5kb,
  count(*) filter (where image_data is not null and octet_length(image_data) >= 12000) as images_12kb_or_more,
  count(*) filter (where image_data is null and coalesce(image_url, '') <> '') as url_only_rows
from public.categories

union all

select
  'erp_item_categories',
  count(*),
  count(*) filter (where image_data is not null),
  count(*) filter (where image_data is not null and octet_length(image_data) < 5000),
  count(*) filter (where image_data is not null and octet_length(image_data) >= 12000),
  count(*) filter (where image_data is null and coalesce(image_url, '') <> '')
from public.erp_item_categories

union all

select
  'erp_items',
  count(*),
  count(*) filter (where image_data is not null),
  count(*) filter (where image_data is not null and octet_length(image_data) < 5000),
  count(*) filter (where image_data is not null and octet_length(image_data) >= 12000),
  count(*) filter (where image_data is null and coalesce(image_url, '') <> '')
from public.erp_items

union all

select
  'products',
  count(*),
  count(*) filter (where image_data is not null),
  count(*) filter (where image_data is not null and octet_length(image_data) < 5000),
  count(*) filter (where image_data is not null and octet_length(image_data) >= 12000),
  count(*) filter (where image_data is null and coalesce(image_url, '') <> '')
from public.products;

-- The largest ERP images are useful candidates for visual inspection.
select
  item_code,
  item_name,
  brand_name,
  package_description,
  image_mime_type,
  octet_length(image_data) as image_bytes,
  source_name,
  source_url
from public.erp_items
where image_data is not null
order by octet_length(image_data) desc
limit 50;

-- Product marketplace readiness: an ERP item is not automatically a customer-facing
-- product. Review supplier identity, active/available flags and image bytes first.
select
  count(*) as customer_products,
  count(*) filter (where image_data is not null) as products_with_binary_images,
  count(*) filter (where is_active and is_available) as active_available_products
from public.products;
