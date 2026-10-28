UPDATE storage.buckets
SET file_size_limit = 52428800,
    allowed_mime_types = ARRAY['image/jpeg','image/png','image/webp','image/gif','video/mp4']::text[]
WHERE id = 'silsila-public-ads';
