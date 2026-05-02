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

Status: blocked safely because the project currently has `0` Supabase Auth users.

No founding DOC profile was created because there is no authenticated user row to bind to `profiles.user_id`. Manually inserting rows into `auth.users` is intentionally avoided.

After the founding Auth user exists, run:

1. Open Supabase Dashboard for project `cgcrkwlexwtrvlliavgn`.
2. Go to Authentication > Users.
3. Create or invite the founding user for Joseph Paez.
4. Confirm the user appears in `auth.users` with the intended email.
5. Open [supabase/scripts/bootstrap_founding_doc.sql](../supabase/scripts/bootstrap_founding_doc.sql).
6. Replace `FOUNDING_USER_EMAIL` with that exact Auth user email.
7. Run the script through the Supabase SQL editor or the authenticated Supabase MCP connection.
8. Verify a `doc` profile exists for `Atletico Dallas`.

Expected founding DOC profile:

- Role: `doc`
- Club ID: `56f736e5-5961-4bb4-a7f6-05417df1cdff`
- First name: `Joseph`
- Last name: `Paez`
- Email: copied from the Auth user row
- Active state: `is_active = true`

DOC profile ID: not created yet because no Auth user exists.

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

Live tests completed:

- Anonymous access remains blocked. `anon` selecting from `public.clubs` returns `permission denied for table clubs`.
- Authenticated access without a profile is restricted. A synthetic authenticated JWT subject with no matching `profiles.user_id` saw `0` clubs, seasons, teams, players, inquiries, and documents.
- Helper functions for an authenticated user without a profile returned `null` for current profile, club, and role, which prevents row access.
- No broad public grants were introduced. `anon` table/view grants: `0`. `PUBLIC` table/view grants: `0`.
- RLS remains enabled on all public base tables.

Tests not completed yet:

- DOC club-wide access was not tested because no founding Auth user exists yet.
- Coach and team manager role tests with real login sessions were not completed because no Auth test accounts exist yet.
- Parent and player role tests were not completed because profile-to-player Auth bindings require real Auth users.

## One-Account-Per-Role Test Plan

Before Rork starts UI work, create or invite one Supabase Auth user for each role:

- `doc`
- `club_manager`
- `head_coach`
- `assistant_coach`
- `team_manager`
- `parent`
- `player`

Use the SQL editor or MCP to bind those Auth users to `profiles.user_id`; do not store passwords or service role keys in the repo.

Recommended setup:

- Bind Joseph's Auth user with [supabase/scripts/bootstrap_founding_doc.sql](../supabase/scripts/bootstrap_founding_doc.sql).
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

- Founding DOC profile cannot be completed until the first Auth user exists.
- QA coach and manager profiles are not login-capable until their `user_id` values are bound to real Auth users.
- Parent/player tests need real parent/player Auth users plus player profile links.
- The QA fixtures are live data and should stay clearly labeled or be removed before production onboarding.

## Exact Next Step Before Rork

Create the founding Supabase Auth user for Joseph Paez, run [supabase/scripts/bootstrap_founding_doc.sql](../supabase/scripts/bootstrap_founding_doc.sql), verify DOC RLS access, then create/bind the remaining six role test accounts and run the one-account-per-role RLS matrix.
