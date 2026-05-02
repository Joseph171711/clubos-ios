# Atletico Dallas Bootstrap Report

Bootstrap date: 2026-05-02

Supabase project: `ClubOS-Final`

Project ref: `cgcrkwlexwtrvlliavgn`

Repository: `Joseph171711/clubos-ios`

Branch: `main`

## Applied Live

Migration applied through the configured Supabase MCP server:

- `20260502105754_bootstrap_atletico_dallas_foundation`
- Live Supabase migration history name: `bootstrap_atletico_dallas_foundation`
- Live Supabase migration history version: `20260502110120`

The migration added `clubs.status`, constrained club status values, created Atletico Dallas, created the active 2026-2027 season, and inserted clearly labeled QA fixtures for backend/RLS readiness.

Founding DOC binding applied live through Supabase MCP on 2026-05-02 using the committed safe bootstrap script logic from [supabase/scripts/bootstrap_founding_doc.sql](../supabase/scripts/bootstrap_founding_doc.sql), with an additional exact UID/email preflight check before binding.

## Real Club Bootstrap

Club:

- Name: `Atletico Dallas`
- Slug: `atletico-dallas`
- Status: `active`
- Club ID: `56f736e5-5961-4bb4-a7f6-05417df1cdff`

Season:

- Name: `2026-2027`
- Start date: `2026-08-01`
- End date: `2027-07-31`
- Is active: `true`
- Season ID: `e3028c5a-ca43-4362-832c-5dd1e57356a9`

## Founding DOC Bootstrap

Status: completed.

Supabase Auth preflight found exactly one matching existing Auth user:

- Auth user ID: `13c06276-028e-4e50-ab93-641bb94388ae`
- Email: `joseph171711@outlook.com`
- Email confirmed at: `2026-05-02T12:34:00.322079+00:00`

Founding DOC profile:

- DOC profile ID: `bb496826-c439-499d-ac3b-773c5245ada9`
- Auth user ID: `13c06276-028e-4e50-ab93-641bb94388ae`
- Club ID: `56f736e5-5961-4bb4-a7f6-05417df1cdff`
- Role: `doc`
- First name: `Joseph`
- Last name: `Paez`
- Email: `joseph171711@outlook.com`
- Active state: `is_active = true`
- Deleted state: `deleted_at = null`

The profile is linked through `profiles.user_id`, so RLS helper functions resolve it through `auth.uid()`.

## QA Fixtures

The following safe QA fixtures were created. They use `.invalid` emails and obvious `QA` names so they are easy to identify or remove later.

- Team: `QA U12 Boys 9v9`
- Team ID: `1125dec3-0af2-4532-ae36-79d3f0e3ebed`
- Head coach profile ID: `9ce482c0-a949-4bcb-ad42-1ab496f2c5d1`
- Team manager profile ID: `ebff5510-6a6a-43af-8cbe-3b917aff6793`
- Player inquiry ID: `de11ab41-5f4b-41a8-889c-93183010d804`
- Rostered player ID: `7a28a5ac-d4e2-40fe-a3f1-c19faefa759d`
- Document requirement ID: `f8931af8-0ea8-470d-b932-c677dcdb3c2b`

Fixture counts verified live:

- Teams: `1`
- QA profiles: `2`
- Team staff assignments: `2`
- Player inquiries: `1`
- Rostered players: `1`
- Document requirements: `1`

## RLS Test Results

Live DOC simulation used `role authenticated` with `auth.uid()` claims set to `13c06276-028e-4e50-ab93-641bb94388ae`.

DOC helper results:

- `private.current_user_profile_id()`: `bb496826-c439-499d-ac3b-773c5245ada9`
- `private.current_user_club_id()`: `56f736e5-5961-4bb4-a7f6-05417df1cdff`
- `private.current_user_role()`: `doc`
- `private.is_doc_or_club_manager()`: `true`

DOC access results:

- Atletico Dallas club records visible: `1`
- Seasons visible: `1`
- Teams visible: `1`
- Players visible: `1`
- Player inquiries visible: `1`
- Documents visible: `0` because no document upload rows exist yet
- Document requirements visible: `1`
- Profiles visible: `3`

Negative access checks:

- Authenticated no-profile access remains blocked. A synthetic authenticated UID with no matching `profiles.user_id` saw `0` clubs, teams, players, player inquiries, documents, and document requirements.
- No-profile helper functions returned `null` for current profile, club, and role.
- Anonymous access remains blocked. `anon` selecting from `public.clubs` returns `permission denied for table clubs`.
- No broad public grants were introduced. `anon` table/view grants: `0`. `PUBLIC` table/view grants: `0`.
- RLS remains enabled on all public base tables.

Tests not completed yet:

- Coach and team manager role tests with real login sessions are still pending because those Auth test accounts are not created/bound yet.
- Parent and player role tests are still pending because profile-to-player Auth bindings require real Auth users.

## One-Account-Per-Role Test Plan

Before Rork starts UI work, create or invite one Supabase Auth user for each remaining role:

- `club_manager`
- `head_coach`
- `assistant_coach`
- `team_manager`
- `parent`
- `player`

Use the SQL editor or MCP to bind those Auth users to `profiles.user_id`; do not store passwords or service role keys in the repo.

Recommended setup:

- Create a `club_manager` profile for Atletico Dallas.
- Bind the QA head coach profile to the head coach Auth user.
- Create an unassigned head coach profile to prove unassigned coaches cannot see players or inquiries.
- Create an assistant coach profile and assign it to the QA team only after the unassigned test passes.
- Bind the QA team manager profile to the team manager Auth user.
- Create parent/player profiles and link them through `players.parent_profile_id` and `players.player_profile_id`.

Expected RLS outcomes:

- DOC and Club Manager can see club-wide records.
- Unassigned coaches and team managers can see limited club/team context but cannot see full player, inquiry, document, match roster, or tournament detail.
- Assigned coaches and team managers can see assigned team/player/pipeline/logistics records.
- Parent and player users can only see their linked player records once profile links exist.
- Anonymous users receive no table/view access.

## Known Limitations

- QA coach and manager profiles are not login-capable until their `user_id` values are bound to real Auth users.
- Parent/player tests need real parent/player Auth users plus player profile links.
- No document upload rows exist yet, so DOC document access is proven through document requirements and grants/RLS, not through actual uploaded document rows.
- The QA fixtures are live data and should stay clearly labeled or be removed before production onboarding.

## Exact Next Step Before Rork

Create and bind the remaining role test accounts, then run the one-account-per-role RLS matrix for `club_manager`, `head_coach`, `assistant_coach`, `team_manager`, `parent`, and `player` before Rork starts building UI flows.
