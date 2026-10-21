-- =============================================================================
-- AXIS: PowerSync Role Permissions & Default Privileges
-- Fixes: "permission denied for table habit_categories / prayers / user_profiles"
-- Grants SELECT to the PowerSync replication role and Supabase API roles.
-- =============================================================================

-- 1. Grant table permissions to Supabase API roles (authenticated, service_role, anon)
GRANT USAGE ON SCHEMA public TO postgres, anon, authenticated, service_role;

GRANT ALL ON TABLE public.habit_categories TO authenticated, service_role, postgres;
GRANT ALL ON TABLE public.prayers TO authenticated, service_role, postgres;
GRANT ALL ON TABLE public.user_profiles TO authenticated, service_role, postgres;

GRANT SELECT ON TABLE public.habit_categories TO anon;
GRANT SELECT ON TABLE public.prayers TO anon;
GRANT SELECT ON TABLE public.user_profiles TO anon;

-- 2. Dynamically grant permissions to PowerSync replication roles
DO $$
DECLARE
  r RECORD;
BEGIN
  -- Grant to 'powersync_role' if it exists (standard Supabase PowerSync guide role)
  IF EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'powersync_role') THEN
    EXECUTE 'GRANT USAGE ON SCHEMA public TO powersync_role';
    EXECUTE 'GRANT SELECT ON ALL TABLES IN SCHEMA public TO powersync_role';
    EXECUTE 'ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT SELECT ON TABLES TO powersync_role';
  END IF;

  -- Grant to 'powersync' if it exists
  IF EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'powersync') THEN
    EXECUTE 'GRANT USAGE ON SCHEMA public TO powersync';
    EXECUTE 'GRANT SELECT ON ALL TABLES IN SCHEMA public TO powersync';
    EXECUTE 'ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT SELECT ON TABLES TO powersync';
  END IF;

  -- Grant to any role that has logical replication permissions in the database
  FOR r IN (SELECT rolname FROM pg_roles WHERE rolreplication = true) LOOP
    BEGIN
      EXECUTE format('GRANT USAGE ON SCHEMA public TO %I', r.rolname);
      EXECUTE format('GRANT SELECT ON ALL TABLES IN SCHEMA public TO %I', r.rolname);
      EXECUTE format('ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT SELECT ON TABLES TO %I', r.rolname);
    EXCEPTION WHEN OTHERS THEN NULL;
    END;
  END LOOP;
END $$;

-- 3. Ensure tables are added to PowerSync logical replication publication
DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM pg_publication WHERE pubname = 'powersync') THEN
    BEGIN
      ALTER PUBLICATION powersync ADD TABLE public.habit_categories;
    EXCEPTION WHEN duplicate_object THEN NULL;
    END;
    BEGIN
      ALTER PUBLICATION powersync ADD TABLE public.prayers;
    EXCEPTION WHEN duplicate_object THEN NULL;
    END;
    BEGIN
      ALTER PUBLICATION powersync ADD TABLE public.user_profiles;
    EXCEPTION WHEN duplicate_object THEN NULL;
    END;
  END IF;

  IF EXISTS (SELECT 1 FROM pg_publication WHERE pubname = 'powersync_axis') THEN
    BEGIN
      ALTER PUBLICATION powersync_axis ADD TABLE public.habit_categories;
    EXCEPTION WHEN duplicate_object THEN NULL;
    END;
    BEGIN
      ALTER PUBLICATION powersync_axis ADD TABLE public.prayers;
    EXCEPTION WHEN duplicate_object THEN NULL;
    END;
    BEGIN
      ALTER PUBLICATION powersync_axis ADD TABLE public.user_profiles;
    EXCEPTION WHEN duplicate_object THEN NULL;
    END;
  END IF;
END $$;
