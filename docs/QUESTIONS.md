# AXIS: Questions & Assumptions

This file records open questions and the simplest decision taken when the spec was ambiguous.

| # | Sprint | Question | Decision |
|---|--------|----------|----------|
| 1 | S01 | Should `archived_at` on `projects` and `habits` follow the same soft-delete convention as `deleted_at`? | Yes – same semantics; queries for active records add `archived_at IS NULL`. |
| 2 | S01 | The `daily_plans` table has no explicit `user_id` column listed in §4.2 but §3.1 says every synced table has it. | Added `user_id` to `daily_plans` and all planning/habit/notes/gamification tables consistent with §3.1 rule. |
