# ClubOS-Final Backend Audit Report

Audit date: 2026-05-02

Target Supabase project: `cgcrkwlexwtrvlliavgn` (`ClubOS-Final`)

Repository: `Joseph171711/clubos-ios`

Branch: `main`

## Migration Application

Applied live to Supabase project `cgcrkwlexwtrvlliavgn`:

- `20260502073831_init_clubos_foundation`
- `20260502073833_seed_clubos_lookups`
- `20260502073835_app_readiness_views`
- `20260502080959_lock_down_app_views`
- `20260502081510_restrict_helper_function_execution`

All migrations completed successfully through the configured Supabase MCP server.

## Schema Audit

Status: passed.

Live verification results:

- Required tables present: 32 of 32.
- Required app-readiness views present: 6 of 6.
- Missing required tables: none.
- Missing required views: none.
- Required foreign keys were created for club, season, team, player, staff/profile, inquiry, document, league, match, and tournament relationships.
- Club-scoped operational tables have `club_id`.
- Operational tables use `created_at`, `updated_at`, and `deleted_at` for app-friendly soft-delete behavior where appropriate.
- Useful indexes exist for `club_id`, team/player ownership, assigned staff, pipeline stage, due dates, document status, and deleted rows.
- Team/player/staff relationships support home teams, sister teams, guest players, training-only assignments, and staff role assignments.
- Competition models support primary and secondary leagues, match kits, match rosters, tournaments, team tournament registration, and tournament deadlines.
- Document records can attach to players, staff profiles, teams, matches, tournaments, and inquiries through constrained owner fields.

No duplicate operational concepts were introduced. Lookup tables handle dropdown values, while enum/check constraints protect core state values.

## RLS Audit

Status: passed, with one documented advisor warning.

Live verification results:

- RLS disabled on required tables: none.
- `anon` policies on user data: none found.
- `anon` table/view grants: none found.
- `anon` helper function execute grants: none found.
- DOC and Club Manager policies exist for full in-club management.
- Coach policies exist for assigned teams, assigned players, assigned inquiries, team logistics, tasks, and documents.
- Team Manager policies exist for assigned team administration, logistics, tasks, and documents.
- Parent and player access is intentionally minimal until profile-to-player linking is implemented.
- Helper functions live in the non-exposed `private` schema and are `SECURITY DEFINER` functions with explicit search paths.

Supabase security advisor result after hardening:

- Remaining warning: `Signed-In Users Can Execute SECURITY DEFINER Function`.
- Reason accepted: authenticated execution is required because RLS policies call private helper functions such as `private.current_user_club_id()` and `private.can_access_player(...)`.
- Public and anonymous execution was revoked; only `authenticated` and `service_role` retain execute on the seven private RLS helper functions.

Policies that should receive live-user testing before production launch:

- Coach updates for assigned inquiries and assigned-player operational fields.
- Team Manager updates for documents, deadlines, match rosters, and logistics records.
- DOC/Club Manager conversion flow from inquiry to player through `convert_inquiry_to_player(...)`.

## Seed Data Audit

Status: passed.

Live seed counts:

- Age groups: 15 (`U4` through `U18`)
- Team formats: 4 (`4v4`, `7v7`, `9v9`, `11v11`)
- Team genders: 3 (`boys`, `girls`, `coed`)
- Team levels: 5 (`academy`, `select`, `pre_ecnl`, `ecnl`, `rec`)
- Pipeline stages: 11, matching the required intake lifecycle
- Task statuses: 5
- Document statuses: 6
- Default document types: 18

No fake/demo clubs, teams, players, parents, staff, matches, or tournaments were seeded.

## App-Readiness Audit

Status: passed for backend foundation.

Supported MVP screens:

- DOC Today
- Coach Today
- Manager Today
- Pipeline Board/List
- Team List
- Team Detail
- Player List
- Player Detail
- Documents
- Match Kit
- Tournament Planner
- Reports

Rork can query lookup tables directly for dropdowns and can use the security-invoker views for dashboard/list summaries:

- `app_doc_today`
- `app_coach_today`
- `app_manager_today`
- `app_pipeline_board`
- `app_team_roster_summary`
- `app_document_queue`

Table and column names are lower_snake_case, descriptive, and suitable for Swift/Rork clients.

Potential future RPCs/views that may make app development smoother:

- A club bootstrap/admin invitation RPC.
- A parent/player profile linking RPC.
- A richer roster-eligibility view that joins player status, document status, home team, sister teams, and age group.
- Storage upload helpers after private document bucket policies are implemented.

## Security Audit

Status: passed for committed artifacts.

Verification results:

- No `.env` file is committed.
- `.env` and `.env.*` are ignored.
- `.env.example` contains only placeholders/public project URL.
- No database password, direct connection string, service role key, secret key, or private key is committed.
- No app code uses a service role key.
- Public/anonymous table, view, and helper-function access is not enabled.
- Storage upload policies are planned but not broadly enabled.

Supabase performance advisor notes:

- `Multiple Permissive Policies` warnings are expected because role-specific policies are intentionally split for readability and app-role behavior.
- `Unindexed Foreign Keys` informational notices should be reviewed after real query patterns are known. The current schema already includes the indexes required for MVP screens and common filters.
- `Auth DB Connection Strategy is not Percentage` is a platform configuration advisory for production readiness, not a schema blocker.

## Validation Notes

- SQL was validated by successful live migration application and live verification queries.
- Supabase MCP advisors were run after migration application.
- Local Supabase CLI lint was not used because the local CLI was not authenticated/linked in this workspace; MCP live execution and advisors were used instead.

## Known Limitations

- Initial club/profile bootstrap is still required before real users can query data under RLS.
- Parent/player portal flows require a secure profile-to-player relationship before broad parent/player access is enabled.
- Supabase Storage metadata tables are ready, but private document bucket policies must be implemented before uploads.
- Some role-specific field edits may need additional RPC functions if Rork requires stricter column-level write control than RLS can express cleanly.
- Final authorization proof should include live test accounts for DOC, Club Manager, Coach, Team Manager, Parent, and Player roles.

## Bootstrap Update

The first real club row and active season were created in migration `20260502105754_bootstrap_atletico_dallas_foundation`. See [bootstrap-report.md](bootstrap-report.md) for the live IDs, QA fixture IDs, and RLS smoke-test results.

## Next Required Step Before Rork

Create the founding Supabase Auth user for Joseph Paez, run [../supabase/scripts/bootstrap_founding_doc.sql](../supabase/scripts/bootstrap_founding_doc.sql), verify DOC RLS access, then test the remaining one-account-per-role RLS matrix before Rork starts building UI flows.
