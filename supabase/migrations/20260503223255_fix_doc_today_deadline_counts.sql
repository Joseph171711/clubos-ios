-- Keep DOC Today deadline counters independent so league roster-upload
-- deadlines cannot be multiplied by tournament deadline rows.

create or replace view public.doc_today_readiness_v
with (security_invoker = true)
as
select
  c.id as club_id,
  s.id as season_id,
  coalesce(team_counts.total_teams, 0) as total_teams,
  coalesce(player_counts.total_players, 0) as total_players,
  coalesce(inquiry_counts.total_open_inquiries, 0) as total_open_inquiries,
  coalesce(task_counts.overdue_pipeline_tasks, 0) as overdue_pipeline_tasks,
  coalesce(inquiry_counts.ready_to_roster_count, 0) as ready_to_roster_count,
  coalesce(team_counts.teams_below_target_count, 0) as teams_below_target_count,
  coalesce(team_counts.teams_critical_count, 0) as teams_critical_count,
  coalesce(document_counts.missing_documents_count, 0) as missing_documents_count,
  coalesce(deadline_counts.upcoming_tournament_deadlines_count, 0) as upcoming_tournament_deadlines_count,
  coalesce(deadline_counts.roster_uploads_due_count, 0) as roster_uploads_due_count,
  coalesce(team_counts.teams_without_league_count, 0) as teams_without_league_count,
  coalesce(team_counts.teams_without_head_coach_count, 0) as teams_without_head_coach_count,
  coalesce(team_counts.teams_without_manager_count, 0) as teams_without_manager_count
from public.clubs c
join public.seasons s
  on s.club_id = c.id
 and s.is_active
 and s.deleted_at is null
left join lateral (
  select
    count(*)::integer as total_teams,
    count(*) filter (where dtr.needed_players > 0)::integer as teams_below_target_count,
    count(*) filter (where dtr.roster_health = 'critical')::integer as teams_critical_count,
    count(*) filter (where dtr.league_count = 0)::integer as teams_without_league_count,
    count(*) filter (where dtr.head_coach_name is null)::integer as teams_without_head_coach_count,
    count(*) filter (where dtr.manager_name is null)::integer as teams_without_manager_count
  from public.doc_team_readiness_v dtr
  where dtr.club_id = c.id
    and dtr.season_id = s.id
) team_counts on true
left join lateral (
  select count(*)::integer as total_players
  from public.players p
  where p.club_id = c.id
    and p.deleted_at is null
    and p.status::text not in ('inactive', 'closed')
) player_counts on true
left join lateral (
  select
    count(*) filter (where i.pipeline_stage not in ('closed', 'rostered'))::integer as total_open_inquiries,
    count(*) filter (where i.pipeline_stage = 'ready_to_roster')::integer as ready_to_roster_count
  from public.player_inquiries i
  where i.club_id = c.id
    and i.deleted_at is null
) inquiry_counts on true
left join lateral (
  select count(*)::integer as overdue_pipeline_tasks
  from public.pipeline_tasks pt
  where pt.club_id = c.id
    and pt.deleted_at is null
    and pt.completed_at is null
    and pt.status not in ('completed', 'canceled')
    and pt.due_at is not null
    and pt.due_at < now()
) task_counts on true
left join lateral (
  select sum(dtr.missing_document_count)::integer as missing_documents_count
  from public.doc_team_readiness_v dtr
  where dtr.club_id = c.id
    and dtr.season_id = s.id
) document_counts on true
left join lateral (
  select
    (
      select count(*)::integer
      from public.team_tournament_deadlines_v ttd
      where ttd.club_id = c.id
        and ttd.deadline_status in ('due_soon', 'upcoming')
        and ttd.due_at <= now() + interval '30 days'
    ) as upcoming_tournament_deadlines_count,
    (
      (
        select count(*)::integer
        from public.team_tournament_deadlines_v ttd
        where ttd.club_id = c.id
          and ttd.deadline_type = 'roster_upload'
          and ttd.deadline_status in ('overdue', 'due_soon', 'upcoming')
          and ttd.due_at <= now() + interval '30 days'
      )
      + (
        select count(*)::integer
        from public.team_leagues tl
        where tl.club_id = c.id
          and tl.deleted_at is null
          and tl.roster_upload_deadline is not null
          and tl.roster_upload_deadline <= now() + interval '30 days'
      )
    ) as roster_uploads_due_count
) deadline_counts on true
where c.deleted_at is null
  and c.id = (select private.current_user_club_id())
  and (select private.is_doc_or_club_manager());

revoke all on public.doc_today_readiness_v from public, anon;
grant select on public.doc_today_readiness_v to authenticated, service_role;
