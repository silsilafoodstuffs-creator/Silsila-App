-- Storage buckets and ownership policies required by StorageService.
-- Apply after the core schema in the Supabase SQL Editor.
BEGIN;

INSERT INTO storage.buckets (id, name, public)
VALUES
  ('products', 'products', TRUE),
  ('offers', 'offers', TRUE),
  ('stories', 'stories', TRUE),
  ('profiles', 'profiles', TRUE)
ON CONFLICT (id) DO UPDATE SET public = EXCLUDED.public;

DROP POLICY IF EXISTS "silsila_public_media_read" ON storage.objects;
CREATE POLICY "silsila_public_media_read" ON storage.objects
FOR SELECT TO anon, authenticated
USING (bucket_id IN ('products', 'offers', 'stories', 'profiles'));

DROP POLICY IF EXISTS "silsila_upload_own_media" ON storage.objects;
CREATE POLICY "silsila_upload_own_media" ON storage.objects
FOR INSERT TO authenticated
WITH CHECK (
  bucket_id IN ('products', 'offers', 'stories', 'profiles')
  AND (storage.foldername(name))[1] = auth.uid()::text
);

DROP POLICY IF EXISTS "silsila_update_own_media" ON storage.objects;
CREATE POLICY "silsila_update_own_media" ON storage.objects
FOR UPDATE TO authenticated
USING (
  bucket_id IN ('products', 'offers', 'stories', 'profiles')
  AND (storage.foldername(name))[1] = auth.uid()::text
)
WITH CHECK (
  bucket_id IN ('products', 'offers', 'stories', 'profiles')
  AND (storage.foldername(name))[1] = auth.uid()::text
);

DROP POLICY IF EXISTS "silsila_delete_own_media" ON storage.objects;
CREATE POLICY "silsila_delete_own_media" ON storage.objects
FOR DELETE TO authenticated
USING (
  bucket_id IN ('products', 'offers', 'stories', 'profiles')
  AND (storage.foldername(name))[1] = auth.uid()::text
);

COMMIT;
