-- =============================================================================
-- Migration: Add is_enabled column to public.habits
-- Description: Adds is_enabled column to public.habits for habit activation/pause sync
-- =============================================================================

-- 1. Add is_enabled column with default true
ALTER TABLE public.habits
  ADD COLUMN IF NOT EXISTS is_enabled boolean NOT NULL DEFAULT true;

-- 2. Ensure PowerSync replication publication includes habits
DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM pg_publication WHERE pubname = 'powersync') THEN
    BEGIN
      ALTER PUBLICATION powersync ADD TABLE public.habits;
    EXCEPTION WHEN duplicate_object THEN NULL;
    END;
  END IF;

  IF EXISTS (SELECT 1 FROM pg_publication WHERE pubname = 'powersync_axis') THEN
    BEGIN
      ALTER PUBLICATION powersync_axis ADD TABLE public.habits;
    EXCEPTION WHEN duplicate_object THEN NULL;
    END;
  END IF;
END $$;

-- 3. Notify PostgREST to reload schema cache
NOTIFY pgrst, 'reload schema';

