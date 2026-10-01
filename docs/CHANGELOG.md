# AXIS: Changelog

## S01: Repository & Database Schema

- Created root repository structure: `docs/`, `contract/`, `backend/`, `mobile/`, `desktop/`
- Initialized Supabase project under `backend/supabase/`
- Wrote initial SQL migration `20261001000000_initial_schema.sql` covering all tables from SPEC.md §4
- Applied Row Level Security (RLS) on every synced table
- Created placeholder docs: `QUESTIONS.md`, `CHANGELOG.md`, `DEPENDENCIES.md`, `IDEAS.md`
- Created `contract/README.md` describing the contract-vector approach
