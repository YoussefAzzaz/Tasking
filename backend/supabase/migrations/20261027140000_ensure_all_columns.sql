-- =============================================================================
-- AXIS: Ensure Missing Columns for Upstream/Downstream Sync Alignment
-- Run this in Supabase SQL Editor if you want all optional columns present in Postgres:
-- 1. tasks: tags
-- 2. notes: category, mood, energy
-- 3. user_profiles: avatar_url
-- =============================================================================

-- 1. Tasks: add tags column if missing
ALTER TABLE public.tasks 
  ADD COLUMN IF NOT EXISTS tags text;

-- 2. Notes: add category, mood, energy if missing
ALTER TABLE public.notes 
  ADD COLUMN IF NOT EXISTS category text DEFAULT 'General',
  ADD COLUMN IF NOT EXISTS mood text,
  ADD COLUMN IF NOT EXISTS energy text;

-- 3. User Profiles: add avatar_url if missing
ALTER TABLE public.user_profiles 
  ADD COLUMN IF NOT EXISTS avatar_url text;

-- Ensure PowerSync replication publication includes all tables
DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM pg_publication WHERE pubname = 'powersync') THEN
    BEGIN
      ALTER PUBLICATION powersync ADD TABLE public.tasks;
    EXCEPTION WHEN duplicate_object THEN NULL;
    END;
    BEGIN
      ALTER PUBLICATION powersync ADD TABLE public.notes;
    EXCEPTION WHEN duplicate_object THEN NULL;
    END;
    BEGIN
      ALTER PUBLICATION powersync ADD TABLE public.user_profiles;
    EXCEPTION WHEN duplicate_object THEN NULL;
    END;
  END IF;

  IF EXISTS (SELECT 1 FROM pg_publication WHERE pubname = 'powersync_axis') THEN
    BEGIN
      ALTER PUBLICATION powersync_axis ADD TABLE public.tasks;
    EXCEPTION WHEN duplicate_object THEN NULL;
    END;
    BEGIN
      ALTER PUBLICATION powersync_axis ADD TABLE public.notes;
    EXCEPTION WHEN duplicate_object THEN NULL;
    END;
    BEGIN
      ALTER PUBLICATION powersync_axis ADD TABLE public.user_profiles;
    EXCEPTION WHEN duplicate_object THEN NULL;
    END;
  END IF;
END $$;
