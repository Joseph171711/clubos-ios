# ClubOS Readiness Views

These views support DOC Today, team cards, compliance summaries, tournament planning, and pipeline risk surfaces in the Rork app. All views are `security_invoker` views, so they use the requesting user's existing RLS access.

No anonymous access is granted.

## `doc_today_readiness_v`

Purpose: one club/active-season summary for DOC Today.

Use it for high-level counters:

- Team and player totals
- Open inquiry and ready-to-roster counts
- Overdue pipeline tasks
- Roster health alerts
- Missing document totals
- Tournament and roster-upload deadline counts
- Teams missing league, head coach, or manager setup

DOC and Club Manager users should query this as a single-row dashboard source.

## `doc_team_readiness_v`

Purpose: one row per team for DOC team cards.

Use it for:

- Roster target, count, needed players, and `roster_health`
- Head coach and manager names
- Staff, league, tournament, document, and competition readiness
- Next tournament deadline
- US Club and USYS missing-document counts

Expected statuses:

- `roster_health`: `critical`, `thin`, `healthy`, `full`, `overloaded`
- `staff_status`: `critical`, `needs_head_coach`, `needs_manager`, `ready`
- `league_status`: `no_league`, `missing_primary`, `ready`
- `competition_readiness`: `ready`, `needs_roster`, `needs_league`, `needs_documents`, `needs_staff`, `critical`

## `team_competition_readiness_v`

Purpose: detailed team competition readiness.

Use it when a team detail screen needs compact readiness chips:

- `roster_readiness`
- `league_readiness`
- `tournament_readiness`
- `document_readiness`
- `staff_readiness`
- `overall_readiness`
- `blockers` as a text array

The `blockers` array is safe to display as simple tags such as `roster`, `documents`, or `overdue_deadlines`.

## `team_tournament_deadlines_v`

Purpose: all tournament deadlines by team.

Use it for tournament planner lists and deadline chips. The view returns tournament identity, team tournament identity, deadline type, due date, `days_until_due`, and normalized deadline status.

Expected `deadline_status` values:

- `overdue`
- `due_soon`
- `upcoming`
- `complete`

## `team_document_readiness_v`

Purpose: team-level document/card readiness by required document type.

Use it for team compliance panels. It returns one row per required document type and counts each owner's latest document state.

The `governing_body` field is derived from document type names when possible:

- `US Club`
- `USYS`
- `null` for club/general documents

## `player_document_status_v`

Purpose: player compliance summary.

Use it for player list badges and player detail compliance sections. It returns status fields for:

- US Club Player Card
- USYS Player Card
- Birth Certificate
- Medical Release
- Liability Waiver

Expected `player_compliance_status` values:

- `compliant`
- `needs_review`
- `expiring_soon`
- `blocked`

## `staff_compliance_status_v`

Purpose: coach/manager compliance summary.

Use it for staff/admin readiness surfaces. It returns assigned team count and status fields for:

- US Club Coach Card
- USYS Coach Card
- SafeSport
- Background Check
- Coaching License

Expected `staff_compliance_status` values:

- `compliant`
- `needs_review`
- `expiring_soon`
- `blocked`

## `pipeline_risk_v`

Purpose: new player intake risk.

Use it for pipeline board warning badges. The view returns assignment names, next action, age of inquiry, age since last contact, and normalized risk.

Expected `risk_status` values:

- `overdue`
- `unassigned`
- `waiting`
- `ready_to_roster`
- `normal`

## `roster_health_v`

Purpose: roster health by team and age group.

Use it when the app only needs roster target/count/fill percentage without the larger DOC team card payload.

The QA team `QA U12 Boys 9v9` verifies the critical state:

- `roster_target = 14`
- `roster_count = 1`
- `roster_health = critical`

## RLS Notes For Rork

DOC and Club Manager profiles can read club-wide rows. Coaches and team managers receive rows only where the underlying policies and helper functions allow assigned-team visibility. Authenticated users without a profile receive zero rows. Anonymous users cannot read these views.

Rork should treat these as read-only app contracts. Mutations should continue to use the normalized base tables or approved RPCs.
