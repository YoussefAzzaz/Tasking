-- Migration: 20261116120000_app_releases_table.sql
-- Provides a cloud database manifest for over-the-air updates
-- with public read access (for guests and authenticated users alike).

CREATE TABLE IF NOT EXISTS public.app_releases (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    version TEXT NOT NULL,
    build_number INTEGER NOT NULL DEFAULT 0,
    platform TEXT NOT NULL DEFAULT 'all',
    download_url TEXT NOT NULL,
    release_name TEXT,
    release_notes TEXT,
    file_size_bytes BIGINT,
    is_mandatory BOOLEAN NOT NULL DEFAULT FALSE,
    min_supported_version TEXT,
    published_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Enable RLS
ALTER TABLE public.app_releases ENABLE ROW LEVEL SECURITY;

-- Allow anyone (anon and authenticated) to read release information
CREATE POLICY "Allow public read access to app_releases"
    ON public.app_releases
    FOR SELECT
    TO anon, authenticated
    USING (true);

-- Index for speedy platform-based latest version lookup
CREATE INDEX IF NOT EXISTS idx_app_releases_platform_build
    ON public.app_releases (platform, build_number DESC);
