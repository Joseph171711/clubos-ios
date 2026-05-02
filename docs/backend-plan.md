# ClubOS-Final Backend Plan

## Purpose

ClubOS-Final is a Director of Coaching operating system for youth soccer club operations. The backend is designed around club-scoped workflows for player intake, team rosters, documents, match-day logistics, tournaments, staff accountability, and DOC reporting.

The database is intentionally not seeded with demo teams, players, parents, or staff. Production data should be entered through authenticated app/admin workflows.

## Schema Structure

All operational records are scoped by `club_id` unless they are global lookup/default tables. The core club tables are:

- `clubs`, `seasons`, `profiles`
- `teams`, `team_staff`, `players`, `roster_assignments`
- `player_inquiries`, `pipeline_tasks`, `trial_events`, `trial_evaluations`, `pipeline_activity_log`
- `document_types`, `documents`, `document_requirements`
- `leagues`, `team_leagues`, `matches`, `match_rosters`
- `tournaments`, `team_tournaments`, `tournament_deadlines`
- `player_status_history`, `roster_movement_log`, `staff_activity_log`

Lookup tables support app dropdowns and constrained values:

- `age_groups`
- `team_levels`
- `team_formats`
- `team_genders`
- `pipeline_stages`
- `task_statuses`
- `document_statuses`

## Player Lifecycle

New interested players start in `player_inquiries`; they are not official `players` yet. Pipeline stages follow:

`new -> assigned -> contacted -> trial_scheduled -> trial_completed -> offered -> registration_pending -> documents_pending -> ready_to_roster -> rostered -> closed`

An inquiry can be assigned to a coach, manager, and/or admin. Staff update `pipeline_stage`, `next_action`, `next_action_due_at`, and related `pipeline_tasks`. Trial scheduling uses `trial_events`; coach feedback uses `trial_evaluations`.

Official player creation is handled by `convert_inquiry_to_player(...)`, and only DOC/Club Manager profiles can run that conversion. Direct player inserts are also limited by RLS to DOC/Club Manager.

## Team, Player, And Staff Relationships

`teams` belong to a `club` and `season`. Teams choose an `age_group`, `gender`, `team_format`, and `level`.

`players` have one official `home_team_id`. Flexible rostering is represented by `roster_assignments`:

- `home_team`
- `sister_team`
- `guest_player`
- `training_only`

Only DOC/Club Manager can change official home-team status. Sister-team and guest-player eligibility can be represented without changing the player home team.

`team_staff` assigns coaches and team managers to teams. This drives RLS for coach/manager access to teams, players, pipeline records, documents, matches, and tournament logistics.

## Document Model

`document_types` stores global defaults and optional club-specific document types. `documents` uses an explicit `owner_type` plus `owner_id` model for required owner categories:

- `player`
- `staff`
- `team`
- `match`
- `tournament`
- `inquiry`

The polymorphic model is documented and intentionally limited to the owner types above. It avoids six separate document tables while keeping one consistent app query surface.

`document_requirements` lets the club define required document rules by owner type, team, age group, or level.

## Competition Model

`leagues` hold league metadata. `team_leagues` connects teams to primary and secondary leagues, with one active primary league per team enforced by a partial unique index.

`matches` support league and tournament fixtures, kit details, arrival/kickoff times, coach notes, and parent-facing logistics. `match_rosters` supports regular, guest, and unavailable players.

`tournaments` store tournament metadata. `team_tournaments` tracks a team entering a tournament, while `tournament_deadlines` tracks registration, payment, roster upload, check-in, hotel, and other due dates.

## App-Readiness Views

Security-invoker views give Rork simple dashboard and list surfaces while preserving underlying RLS:

- `app_doc_today`
- `app_coach_today`
- `app_manager_today`
- `app_pipeline_board`
- `app_team_roster_summary`
- `app_document_queue`

These views are helpers, not a replacement for normalized tables. Rork can query either the views or the base tables depending on screen complexity.
