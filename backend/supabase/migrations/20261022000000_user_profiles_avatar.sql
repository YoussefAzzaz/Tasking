-- =============================================================================
-- AXIS: User Profile Picture & Storage Migration
-- 1. Adds avatar_url column to public.user_profiles
-- 2. Creates avatars storage bucket with 5MB size limit & image mime types
-- 3. Configures Row Level Security (RLS) on storage.objects for avatars
-- =============================================================================

-- 1. Add avatar_url column to user_profiles
ALTER TABLE public.user_profiles
  ADD COLUMN IF NOT EXISTS avatar_url text;

-- 2. Configure Storage Bucket
INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES (
  'avatars',
  'avatars',
  true,
  5242880,
  ARRAY['image/jpeg', 'image/png', 'image/webp', 'image/gif']
)
ON CONFLICT (id) DO UPDATE SET
  public = EXCLUDED.public,
  file_size_limit = EXCLUDED.file_size_limit,
  allowed_mime_types = EXCLUDED.allowed_mime_types;

-- 3. Storage Row Level Security
-- Public read access to avatars
DROP POLICY IF EXISTS "avatars_public_select" ON storage.objects;
CREATE POLICY "avatars_public_select" ON storage.objects
  FOR SELECT
  USING (bucket_id = 'avatars');

-- Authenticated users can upload avatars inside their own user folder: avatars/{user_id}/*
DROP POLICY IF EXISTS "avatars_owner_insert" ON storage.objects;
CREATE POLICY "avatars_owner_insert" ON storage.objects
  FOR INSERT TO authenticated
  WITH CHECK (
    bucket_id = 'avatars'
    AND (storage.foldername(name))[1] = (SELECT auth.uid()::text)
  );

-- Authenticated users can update/overwrite (upsert) their own avatar
DROP POLICY IF EXISTS "avatars_owner_update" ON storage.objects;
CREATE POLICY "avatars_owner_update" ON storage.objects
  FOR UPDATE TO authenticated
  USING (
    bucket_id = 'avatars'
    AND (storage.foldername(name))[1] = (SELECT auth.uid()::text)
  )
  WITH CHECK (
    bucket_id = 'avatars'
    AND (storage.foldername(name))[1] = (SELECT auth.uid()::text)
  );

-- Authenticated users can delete their own avatar
DROP POLICY IF EXISTS "avatars_owner_delete" ON storage.objects;
CREATE POLICY "avatars_owner_delete" ON storage.objects
  FOR DELETE TO authenticated
  USING (
    bucket_id = 'avatars'
    AND (storage.foldername(name))[1] = (SELECT auth.uid()::text)
  );
