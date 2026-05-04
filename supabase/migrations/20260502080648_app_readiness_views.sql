begin;

create or replace view public.app_doc_today
with (security_invoker = true)
as
select
  c.id as club_id,
  c.name as club_name,
  (
    select count(*)
    from public.player_inquiries i
    where i.club_id = c.id
      and i.deleted_at is null
      and i.pipeline_stage not in ('rostered', 'closed')
  ) as open_inquiries_count,
  (
    select count(*)
    from public.pipeline_tasks pt
    where pt.club_id = c.id
      and pt.deleted_at is null
      and pt.status not in ('completed', 'canceled')
      and pt.due_at <= now() + interval '7 days'
  ) as upcoming_pipeline_tasks_count,
  (
    select count(*)
    from public.documents d
    where d.club_id = c.id
      and d.deleted_at is null
      and d.status in ('missing', 'rejected', 'expired', 'expiring_soon')
  ) as document_issues_count,
  (
    select count(*)
    from public.matches m
    where m.club_id = c.id
      and m.deleted_at is null
      and m.status = 'scheduled'
      and m.match_date between current_date and current_date + 7
  ) as matches_next_7_days_count,
  (
    select count(*)
    from public.tournament_deadlines td
    where td.club_id = c.id
      and td.deleted_at is null
      and td.status not in ('completed', 'canceled')
      and td.due_at <= now() + interval '14 days'
  ) as tournament_deadlines_next_14_days_count
from public.clubs c
where c.deleted_at is null;

create or replace view public.app_coach_today
with (security_invoker = true)
as
select
  ts.profile_id,
  ts.club_id,
  t.id as team_id,
  t.team_name,
  t.age_group,
  t.gender,
  t.team_format,
  t.level,
  (
    select count(*)
    from public.matches m
    where m.team_id = t.id
      and m.deleted_at is null
      and m.status = 'scheduled'
      and m.match_date between current_date and current_date + 7
  ) as matches_next_7_days_count,
  (
    select count(*)
    from public.player_inquiries i
    where i.interested_team_id = t.id
      and i.deleted_at is null
      and i.pipeline_stage in ('assigned', 'contacted', 'trial_scheduled', 'trial_completed')
  ) as active_pipeline_count,
  (
    select count(*)
    from public.documents d
    where d.club_id = t.club_id
      and d.deleted_at is null
      and d.owner_type = 'team'
      and d.owner_id = t.id
      and d.status in ('missing', 'rejected', 'expired', 'expiring_soon')
  ) as team_document_issues_count
from public.team_staff ts
join public.teams t on t.id = ts.team_id
where ts.deleted_at is null
  and t.deleted_at is null
  and ts.role in ('head_coach', 'assistant_coach');

create or replace view public.app_manager_today
with (security_invoker = true)
as
select
  ts.profile_id,
  ts.club_id,
  t.id as team_id,
  t.team_name,
  (
    select count(*)
    from public.matches m
    where m.team_id = t.id
      and m.deleted_at is null
      and m.status = 'scheduled'
      and m.match_date between current_date and current_date + 7
  ) as match_kit_items_count,
  (
    select count(*)
    from public.team_tournaments tt
    join public.tournament_deadlines td on td.team_tournament_id = tt.id
    where tt.team_id = t.id
      and tt.deleted_at is null
      and td.deleted_at is null
      and td.status not in ('completed', 'canceled')
      and td.due_at <= now() + interval '14 days'
  ) as tournament_deadlines_next_14_days_count,
  (
    select count(*)
    from public.documents d
    where d.club_id = t.club_id
      and d.deleted_at is null
      and d.owner_type in ('team', 'match', 'tournament')
      and d.status in ('missing', 'rejected', 'expired', 'expiring_soon')
  ) as logistics_document_issues_count
from public.team_staff ts
join public.teams t on t.id = ts.team_id
where ts.deleted_at is null
  and t.deleted_at is null
  and ts.role = 'team_manager';

create or replace view public.app_pipeline_board
with (security_invoker = true)
as
select
  i.id,
  i.club_id,
  i.player_first_name,
  i.player_last_name,
  i.preferred_name,
  i.gender,
  i.interested_age_group,
  i.interested_team_id,
  t.team_name as interested_team_name,
  i.pipeline_stage,
  ps.sort_order as pipeline_stage_sort_order,
  i.priority,
  i.next_action,
  i.next_action_due_at,
  i.last_contacted_at,
  i.trial_date,
  i.assigned_coach_id,
  coach.first_name || ' ' || coach.last_name as assigned_coach_name,
  i.assigned_manager_id,
  manager.first_name || ' ' || manager.last_name as assigned_manager_name,
  i.assigned_admin_id,
  admin.first_name || ' ' || admin.last_name as assigned_admin_name,
  (
    select count(*)
    from public.pipeline_tasks pt
    where pt.inquiry_id = i.id
      and pt.deleted_at is null
      and pt.status not in ('completed', 'canceled')
  ) as open_task_count
from public.player_inquiries i
join public.pipeline_stages ps on ps.id = i.pipeline_stage
left join public.teams t on t.id = i.interested_team_id
left join public.profiles coach on coach.id = i.assigned_coach_id
left join public.profiles manager on manager.id = i.assigned_manager_id
left join public.profiles admin on admin.id = i.assigned_admin_id
where i.deleted_at is null;

create or replace view public.app_team_roster_summary
with (security_invoker = true)
as
select
  t.id as team_id,
  t.club_id,
  t.season_id,
  t.team_name,
  t.age_group,
  t.birth_year,
  t.gender,
  t.team_format,
  t.level,
  t.roster_target,
  count(ra.id) filter (
    where ra.deleted_at is null
      and (ra.end_date is null or ra.end_date >= current_date)
  ) as active_roster_count,
  count(ra.id) filter (
    where ra.deleted_at is null
      and ra.assignment_type = 'home_team'
      and (ra.end_date is null or ra.end_date >= current_date)
  ) as home_roster_count,
  count(ra.id) filter (
    where ra.deleted_at is null
      and ra.assignment_type = 'sister_team'
      and (ra.end_date is null or ra.end_date >= current_date)
  ) as sister_team_eligible_count
from public.teams t
left join public.roster_assignments ra on ra.team_id = t.id
where t.deleted_at is null
group by
  t.id,
  t.club_id,
  t.season_id,
  t.team_name,
  t.age_group,
  t.birth_year,
  t.gender,
  t.team_format,
  t.level,
  t.roster_target;

create or replace view public.app_document_queue
with (security_invoker = true)
as
select
  d.id,
  d.club_id,
  d.owner_type,
  d.owner_id,
  dt.name as document_type_name,
  d.status,
  d.file_name,
  d.uploaded_by_profile_id,
  d.reviewed_by_profile_id,
  d.reviewed_at,
  d.expires_at,
  d.notes,
  d.created_at,
  d.updated_at
from public.documents d
join public.document_types dt on dt.id = d.document_type_id
where d.deleted_at is null
  and d.status in ('missing', 'uploaded', 'rejected', 'expired', 'expiring_soon');

grant select on
  public.app_doc_today,
  public.app_coach_today,
  public.app_manager_today,
  public.app_pipeline_board,
  public.app_team_roster_summary,
  public.app_document_queue
to authenticated, service_role;

commit;
