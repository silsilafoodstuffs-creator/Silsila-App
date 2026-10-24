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

-- Detect repeated binary payloads assigned to different ERP items. A non-null
-- image_data column is not enough: seed/placeholder images may be reused across
-- unrelated products and create a misleading "all images present" result.
select
  count(*) as duplicate_image_groups,
  coalesce(sum(row_count - 1), 0) as extra_rows_reusing_an_image
from (
  select md5(encode(image_data, 'base64')) as image_hash, count(*) as row_count
  from public.erp_items
  where image_data is not null
  group by md5(encode(image_data, 'base64'))
  having count(*) > 1
) repeated;

-- List the duplicated image assignments for manual remediation. This is read-only.
select
  md5(encode(image_data, 'base64')) as image_hash,
  count(*) as assigned_item_count,
  array_agg(item_code order by item_code) as item_codes,
  array_agg(item_name order by item_code) as item_names,
  min(octet_length(image_data)) as min_bytes,
  max(octet_length(image_data)) as max_bytes
from public.erp_items
where image_data is not null
group by md5(encode(image_data, 'base64'))
having count(*) > 1
order by assigned_item_count desc, min_bytes asc
limit 100;

-- Very small PNGs often indicate generic icons/placeholder illustrations rather
-- than product-pack photography. Review these records before treating them as
-- completed real-image imports.
select item_code, item_name, brand_name, package_description,
       image_mime_type, octet_length(image_data) as image_bytes
from public.erp_items
where image_data is not null
  and image_mime_type = 'image/png'
  and octet_length(image_data) < 5000
order by octet_length(image_data), item_code
limit 200;

