# ClubOS-Final RLS Plan

## Security Model

RLS is enabled on every user-facing table in `public`. No policies are granted to `anon`; app data access is for authenticated users only. Table grants expose objects to the authenticated Data API role, and RLS determines which rows are visible or writable.

Helper functions live in the non-exposed `private` schema and are used by policies:

- `private.current_user_profile_id()`
- `private.current_user_club_id()`
- `private.current_user_role()`
- `private.is_doc_or_club_manager()`
- `private.is_team_staff(team_id)`
- `private.can_access_player(player_id)`
- `private.can_access_inquiry(inquiry_id)`

Additional internal helpers cover match, tournament, and document access. Functions use `SECURITY DEFINER` only where needed to evaluate profile/team membership safely without recursive RLS lookups.

## Role Permissions

DOC and Club Manager:

- View and manage all records inside their club.
- Create/update teams, seasons, profiles, roster assignments, documents, matches, tournaments, and requirements.
- Convert inquiries to official players.
- Change official player home teams.

Head Coach and Assistant Coach:

- View assigned teams.
- View/update assigned player records and roster logistics for assigned teams.
- View/update assigned player inquiries, trial events, trial evaluations, and pipeline tasks.
- View documents connected to accessible players, inquiries, teams, matches, and tournaments.

Team Manager:

- View assigned team operations.
- Update assigned team logistics, match kit records, tournament deadlines, documents, and tasks.
- View player/team details needed for team administration.
- Does not receive broad club-wide player/contact/document access.

Parent and Player:

- The schema supports optional `parent_profile_id` and `player_profile_id` links on `players`.
- Parent/player access is limited to the linked player record and related documents once those profile links exist.

## What Is Not Public

No tables are intentionally readable by unauthenticated users. Public intake should be added later through a controlled Edge Function or explicit public form workflow, not direct table access.

No service-role key belongs in app code. The iOS/Rork app should use the Supabase URL and publishable/anon client key only. RLS remains the authorization boundary.

## Column-Level Caveat

Postgres RLS controls rows, not individual columns. To protect high-risk operations, triggers enforce these rules:

- Non-DOC/Club Manager users cannot change a player's `home_team_id`.
- Non-DOC/Club Manager users cannot change a player to `rostered`.
- Non-DOC/Club Manager users cannot create/change official home-team roster assignments.

Future sensitive field edits can be moved into RPC functions if the UI needs tighter column-level workflows.

## Storage Plan

Document metadata is implemented in `documents`, but broad Supabase Storage policies are intentionally not enabled yet. Before uploads go live:

- Create a private storage bucket for club documents.
- Store object paths under `club_id/owner_type/owner_id/...`.
- Add storage policies that call the same access logic used by `documents`.
- Keep service-role upload/review tasks server-side only.
