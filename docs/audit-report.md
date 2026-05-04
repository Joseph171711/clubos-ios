# ClubOS-Final Backend Audit Report

Audit date: 2026-05-04

Target Supabase project: `cgcrkwlexwtrvlliavgn` (`ClubOS-Final`)

Repository: `Joseph171711/clubos-ios`

Branch: `main`

## Migration Application

Applied live to Supabase project `cgcrkwlexwtrvlliavgn`:

- `20260502080431_init_clubos_foundation`
- `20260502080542_seed_clubos_lookups`
- `20260502080648_app_readiness_views`
- `20260502081040_lock_down_app_views`
- `20260502081544_restrict_helper_function_execution`
- `20260502110120_bootstrap_atletico_dallas_foundation`
- `20260503222601_test_literal_noop`
- `20260503222949_doc_readiness_intelligence_views`
- `20260503223349_fix_doc_today_deadline_counts`
- `20260504025207_harden_rls_auto_enable_function`

All migrations completed successfully through the configured Supabase MCP server.

## Schema Audit

Status: passed.

Live verification results:

- Required operational tables present: 25 of 25.
- Lookup tables present: 7 of 7.
- Required app-readiness views present: 6 of 6.
- DOC intelligence views present: 9 of 9.
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
- Public and anonymous execution was revoked; only `authenticated` and `service_role` retain execute on the private RLS helper functions required by policies.
- The Supabase `ensure_rls` event trigger helper was moved from `public.rls_auto_enable()` to `private.rls_auto_enable()` and app-role execution was revoked in migration `20260504025207_harden_rls_auto_enable_function`.

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

Rork can query DOC readiness and intelligence views for operational summaries:

- `doc_today_readiness_v`
- `doc_team_readiness_v`
- `team_competition_readiness_v`
- `team_tournament_deadlines_v`
- `team_document_readiness_v`
- `player_document_status_v`
- `staff_compliance_status_v`
- `pipeline_risk_v`
- `roster_health_v`

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
- Local Supabase CLI lint was not used because the `supabase` CLI is not installed in this workspace; MCP live execution and verification queries were used instead.

DOC intelligence validation on 2026-05-04:

- All 9 readiness views exist live and have `security_invoker=true`.
- DOC user `13c06276-028e-4e50-ab93-641bb94388ae` sees 1 `doc_today_readiness_v` row for Atletico Dallas.
- `doc_team_readiness_v` returns `QA U12 Boys 9v9` with `roster_count = 1` and `roster_health = critical`.
- `team_tournament_deadlines_v` returns 4 QA tournament deadline rows.
- QA readiness seed counts: 1 league, 1 team league, 1 tournament, 1 team tournament, 4 tournament deadlines, and 12 team-scoped document requirements.
- Authenticated no-profile access returns 0 rows from the readiness views.
- Anonymous access receives `permission denied` and has no table/view grants.

## Known Limitations

- Founding DOC bootstrap is complete for Joseph Paez; additional role-specific test accounts are still needed for full one-account-per-role RLS testing.
- Parent/player portal flows require a secure profile-to-player relationship before broad parent/player access is enabled.
- Supabase Storage metadata tables are ready, but private document bucket policies must be implemented before uploads.
- Some role-specific field edits may need additional RPC functions if Rork requires stricter column-level write control than RLS can express cleanly.
- Final authorization proof should include live test accounts for DOC, Club Manager, Coach, Team Manager, Parent, and Player roles.

## Bootstrap Update

The first real club row and active season were created in migration `20260502110120_bootstrap_atletico_dallas_foundation`. See [bootstrap-report.md](bootstrap-report.md) for the live IDs, QA fixture IDs, and RLS smoke-test results.

## DOC Intelligence Update

Migration `20260503222949_doc_readiness_intelligence_views` added DOC readiness, competition, document compliance, staff compliance, pipeline risk, and roster health views. It also added safe QA competition/compliance data for Atletico Dallas so Rork has non-production readiness rows to render.

Migration `20260503223349_fix_doc_today_deadline_counts` keeps DOC Today roster-upload deadline counts independent from tournament deadline row counts.

Migration `20260503222601_test_literal_noop` is a no-op (`select 1;`) that records a harmless MCP connector verification step so Git migration history remains aligned with live Supabase migration history.

Migration `20260504025207_harden_rls_auto_enable_function` keeps the live Supabase RLS event trigger helper in the non-exposed `private` schema and removes app-role execute privileges from that helper.

## Next Required Step Before Rork

Point Rork's DOC Today and Team Detail surfaces at the readiness views, then create/bind the remaining role test accounts to verify coach, manager, parent, and player row visibility end to end.
