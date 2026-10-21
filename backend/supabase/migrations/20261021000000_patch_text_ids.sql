-- =============================================================================
-- Migration: Change primary key ID columns from UUID to TEXT
-- Allows PowerSync client-generated UUIDs, deterministic UUIDs, and custom IDs
-- without type mismatch errors or sync queue deadlocks.
-- =============================================================================

ALTER TABLE public.tasks ALTER COLUMN id TYPE text;
ALTER TABLE public.tasks ALTER COLUMN id SET DEFAULT gen_random_uuid()::text;

ALTER TABLE public.projects ALTER COLUMN id TYPE text;
ALTER TABLE public.projects ALTER COLUMN id SET DEFAULT gen_random_uuid()::text;

ALTER TABLE public.tags ALTER COLUMN id TYPE text;
ALTER TABLE public.tags ALTER COLUMN id SET DEFAULT gen_random_uuid()::text;

ALTER TABLE public.habits ALTER COLUMN id TYPE text;
ALTER TABLE public.habits ALTER COLUMN id SET DEFAULT gen_random_uuid()::text;

ALTER TABLE public.habit_logs ALTER COLUMN id TYPE text;
ALTER TABLE public.habit_logs ALTER COLUMN id SET DEFAULT gen_random_uuid()::text;

ALTER TABLE public.notes ALTER COLUMN id TYPE text;
ALTER TABLE public.notes ALTER COLUMN id SET DEFAULT gen_random_uuid()::text;

ALTER TABLE public.focus_sessions ALTER COLUMN id TYPE text;
ALTER TABLE public.focus_sessions ALTER COLUMN id SET DEFAULT gen_random_uuid()::text;

ALTER TABLE public.logs ALTER COLUMN id TYPE text;
ALTER TABLE public.logs ALTER COLUMN id SET DEFAULT gen_random_uuid()::text;
