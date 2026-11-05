-- =============================================================================
-- AXIS: Enable REPLICA IDENTITY FULL for Realtime Tables under RLS
-- When Row-Level Security (RLS) is enabled on tables subscribed to Supabase Realtime,
-- Postgres requires REPLICA IDENTITY FULL to evaluate row security policies and
-- include full row data (including user_id and unchanged columns) in UPDATE/DELETE events.
-- =============================================================================

ALTER TABLE public.daily_prayer_status REPLICA IDENTITY FULL;
ALTER TABLE public.friend_activity_logs REPLICA IDENTITY FULL;
ALTER TABLE public.friendships REPLICA IDENTITY FULL;
ALTER TABLE public.user_profiles REPLICA IDENTITY FULL;

