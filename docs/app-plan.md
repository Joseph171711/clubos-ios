# ClubOS-Final App Plan

## MVP Screens

Rork should build authenticated role-based navigation around these backend-ready screens:

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

## Role-Based Navigation

DOC and Club Manager:

- Club-wide dashboard, alerts, player pipeline, teams, documents, match/tournament operations, reports, staff activity.

Coach:

- Coach Today, assigned teams, assigned players, trials/evaluations, match notes, pipeline follow-ups.

Team Manager:

- Manager Today, assigned team logistics, documents, match kit, tournament deadlines, roster availability.

Parent/Player:

- Later phase. The schema supports profile links, but the first Rork build should prioritize staff/DOC operations.

## Build Phases

Phase 1:

- Auth shell and profile bootstrap.
- DOC Today, Coach Today, Manager Today.
- Team list/detail and player list/detail.
- Player pipeline board/list.

Phase 2:

- Document metadata workflows and review queues.
- Match Kit with roster availability and kit notes.
- Tournament Planner with deadlines.

Phase 3:

- Parent/player self-service.
- Storage uploads with private bucket policies.
- Push notifications and reminders.
- More detailed reporting.

## Rork Query Notes

Dropdowns can come directly from:

- `age_groups`
- `team_formats`
- `team_genders`
- `team_levels`
- `pipeline_stages`
- `task_statuses`
- `document_statuses`
- `document_types`

Dashboard helpers:

- `app_doc_today`
- `app_coach_today`
- `app_manager_today`
- `app_pipeline_board`
- `app_team_roster_summary`
- `app_document_queue`

Rork should use soft-delete filters (`deleted_at is null`) on direct table queries. The app should not hard-delete operational records.

## Required Step Before UI Build

Create the first club, season, and DOC/Club Manager profile linked to the authenticated Supabase user. Without that bootstrap profile, RLS correctly denies app data access.
