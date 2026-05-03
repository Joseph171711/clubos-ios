-- DOC readiness and competition/compliance intelligence views.
-- These views are security-invoker views so they evaluate the existing table RLS
-- policies and private helper functions as the requesting user.

do $$
declare
  v_club_id uuid;
  v_season_id uuid;
  v_team_id uuid;
  v_league_id uuid;
  v_tournament_id uuid;
  v_team_tournament_id uuid;
  v_document_type_id uuid;
  v_requirement record;
begin
  select id
  into v_club_id
  from public.clubs
  where slug = 'atletico-dallas'
    and deleted_at is null;

  if v_club_id is null then
    raise exception 'Atletico Dallas club row is required before DOC readiness migration can seed QA data.';
  end if;

  select id
  into v_season_id
  from public.seasons
  where club_id = v_club_id
    and name = '2026-2027'
    and deleted_at is null;

  if v_season_id is null then
    raise exception 'Atletico Dallas 2026-2027 season is required before DOC readiness migration can seed QA data.';
  end if;

  select id
  into v_team_id
  from public.teams
  where club_id = v_club_id
    and season_id = v_season_id
    and team_name = 'QA U12 Boys 9v9'
    and deleted_at is null;

  if v_team_id is null then
    raise exception 'QA U12 Boys 9v9 team is required before DOC readiness migration can seed QA data.';
  end if;

  insert into public.leagues (
    club_id,
    name,
    governing_body,
    season_id,
    notes
  )
  values (
    v_club_id,
    'QA North Texas League',
    'US Club Soccer',
    v_season_id,
    'QA fixture for DOC readiness and competition intelligence views.'
  )
  on conflict (club_id, name, season_id) do update
  set
    governing_body = excluded.governing_body,
    notes = excluded.notes,
    deleted_at = null,
    updated_at = now()
  returning id into v_league_id;

  if not exists (
    select 1
    from public.team_leagues
    where club_id = v_club_id
      and team_id = v_team_id
      and league_id = v_league_id
      and league_role = 'primary'
      and deleted_at is null
  ) then
    insert into public.team_leagues (
      club_id,
      team_id,
      league_id,
      league_role,
      registration_status,
      roster_upload_deadline,
      schedule_release_date,
      notes
    )
    values (
      v_club_id,
      v_team_id,
      v_league_id,
      'primary',
      'registered',
      timestamptz '2026-08-20 15:00:00+00',
      date '2026-08-15',
      'QA fixture primary league registration.'
    );
  end if;

  insert into public.tournaments (
    club_id,
    name,
    start_date,
    end_date,
    location,
    governing_body,
    notes
  )
  values (
    v_club_id,
    'QA Labor Day Classic',
    date '2026-09-05',
    date '2026-09-07',
    'Dallas, TX',
    'USYS',
    'QA fixture for tournament deadline readiness views.'
  )
  on conflict (club_id, name, start_date) do update
  set
    end_date = excluded.end_date,
    location = excluded.location,
    governing_body = excluded.governing_body,
    notes = excluded.notes,
    deleted_at = null,
    updated_at = now()
  returning id into v_tournament_id;

  insert into public.team_tournaments (
    club_id,
    team_id,
    tournament_id,
    status,
    cost,
    notes
  )
  values (
    v_club_id,
    v_team_id,
    v_tournament_id,
    'accepted',
    725.00,
    'QA fixture team tournament entry.'
  )
  on conflict (team_id, tournament_id) do update
  set
    status = excluded.status,
    cost = excluded.cost,
    notes = excluded.notes,
    deleted_at = null,
    updated_at = now()
  returning id into v_team_tournament_id;

  if not exists (
    select 1
    from public.tournament_deadlines
    where club_id = v_club_id
      and team_tournament_id = v_team_tournament_id
      and deadline_type = 'registration'
      and deleted_at is null
  ) then
    insert into public.tournament_deadlines (
      club_id,
      team_tournament_id,
      deadline_type,
      due_at,
      status,
      notes
    )
    values (
      v_club_id,
      v_team_tournament_id,
      'registration',
      timestamptz '2026-08-10 15:00:00+00',
      'open',
      'QA tournament registration deadline.'
    );
  end if;

  if not exists (
    select 1
    from public.tournament_deadlines
    where club_id = v_club_id
      and team_tournament_id = v_team_tournament_id
      and deadline_type = 'payment'
      and deleted_at is null
  ) then
    insert into public.tournament_deadlines (
      club_id,
      team_tournament_id,
      deadline_type,
      due_at,
      status,
      notes
    )
    values (
      v_club_id,
      v_team_tournament_id,
      'payment',
      timestamptz '2026-08-15 15:00:00+00',
      'open',
      'QA tournament payment deadline.'
    );
  end if;

  if not exists (
    select 1
    from public.tournament_deadlines
    where club_id = v_club_id
      and team_tournament_id = v_team_tournament_id
      and deadline_type = 'roster_upload'
      and deleted_at is null
  ) then
    insert into public.tournament_deadlines (
      club_id,
      team_tournament_id,
      deadline_type,
      due_at,
      status,
      notes
    )
    values (
      v_club_id,
      v_team_tournament_id,
      'roster_upload',
      timestamptz '2026-08-25 15:00:00+00',
      'open',
      'QA tournament roster upload deadline.'
    );
  end if;

  if not exists (
    select 1
    from public.tournament_deadlines
    where club_id = v_club_id
      and team_tournament_id = v_team_tournament_id
      and deadline_type = 'check_in'
      and deleted_at is null
  ) then
    insert into public.tournament_deadlines (
      club_id,
      team_tournament_id,
      deadline_type,
      due_at,
      status,
      notes
    )
    values (
      v_club_id,
      v_team_tournament_id,
      'check_in',
      timestamptz '2026-09-01 15:00:00+00',
      'open',
      'QA tournament check-in deadline.'
    );
  end if;

  for v_requirement in
    select *
    from (
      values
        ('US Club Player Card', 'player'::public.document_owner_type),
        ('USYS Player Card', 'player'::public.document_owner_type),
        ('Birth Certificate', 'player'::public.document_owner_type),
        ('Medical Release', 'player'::public.document_owner_type),
        ('Liability Waiver', 'player'::public.document_owner_type),
        ('US Club Coach Card', 'staff'::public.document_owner_type),
        ('USYS Coach Card', 'staff'::public.document_owner_type),
        ('SafeSport', 'staff'::public.document_owner_type),
        ('Background Check', 'staff'::public.document_owner_type),
        ('Coaching License', 'staff'::public.document_owner_type),
        ('US Club Team Roster', 'team'::public.document_owner_type),
        ('USYS Team Roster', 'team'::public.document_owner_type)
    ) as r(document_type_name, owner_type)
  loop
    select id
    into v_document_type_id
    from public.document_types
    where club_id is null
      and name = v_requirement.document_type_name
      and deleted_at is null
    limit 1;

    if v_document_type_id is null then
      raise exception 'Default document type % is missing.', v_requirement.document_type_name;
    end if;

    if not exists (
      select 1
      from public.document_requirements
      where club_id = v_club_id
        and document_type_id = v_document_type_id
        and owner_type = v_requirement.owner_type
        and team_id = v_team_id
        and deleted_at is null
    ) then
      insert into public.document_requirements (
        club_id,
        document_type_id,
        owner_type,
        age_group,
        team_level,
        team_id,
        is_required,
        due_at,
        notes
      )
      values (
        v_club_id,
        v_document_type_id,
        v_requirement.owner_type,
        case when v_requirement.owner_type in ('player', 'team') then 'U12' else null end,
        case when v_requirement.owner_type in ('player', 'team') then 'select' else null end,
        v_team_id,
        true,
        timestamptz '2026-08-15 15:00:00+00',
        'QA fixture requirement for DOC readiness and compliance views.'
      );
    end if;
  end loop;
end;
$$;

drop view if exists public.doc_today_readiness_v;
drop view if exists public.team_competition_readiness_v;
drop view if exists public.doc_team_readiness_v;
drop view if exists public.pipeline_risk_v;
drop view if exists public.staff_compliance_status_v;
drop view if exists public.player_document_status_v;
drop view if exists public.team_document_readiness_v;
drop view if exists public.team_tournament_deadlines_v;
drop view if exists public.roster_health_v;

create view public.roster_health_v
with (security_invoker = true)
as
with accessible_teams as (
  select t.*
  from public.teams t
  where t.deleted_at is null
    and t.club_id = (select private.current_user_club_id())
    and (
      (select private.is_doc_or_club_manager())
      or (select private.is_team_staff(t.id))
    )
),
rostered_players as (
  select t.id as team_id, p.id as player_id
  from accessible_teams t
  join public.players p
    on p.home_team_id = t.id
   and p.club_id = t.club_id
   and p.deleted_at is null
   and p.status::text not in ('inactive', 'closed')
  union
  select t.id as team_id, p.id as player_id
  from accessible_teams t
  join public.roster_assignments ra
    on ra.team_id = t.id
   and ra.club_id = t.club_id
   and ra.deleted_at is null
   and ra.assignment_type = 'home_team'
   and ra.is_home_team
   and (ra.start_date is null or ra.start_date <= current_date)
   and (ra.end_date is null or ra.end_date >= current_date)
  join public.players p
    on p.id = ra.player_id
   and p.club_id = t.club_id
   and p.deleted_at is null
   and p.status::text not in ('inactive', 'closed')
),
roster_counts as (
  select team_id, count(distinct player_id)::integer as roster_count
  from rostered_players
  group by team_id
)
select
  t.club_id,
  t.season_id,
  t.id as team_id,
  t.team_name,
  t.age_group,
  t.gender,
  t.team_format,
  t.level,
  t.roster_target,
  coalesce(rc.roster_count, 0) as roster_count,
  greatest(coalesce(t.roster_target, 0) - coalesce(rc.roster_count, 0), 0) as needed_players,
  case
    when t.roster_target is null or t.roster_target <= 0 then null
    else round((coalesce(rc.roster_count, 0)::numeric / t.roster_target::numeric) * 100, 1)
  end as fill_percentage,
  case
    when t.roster_target is null or t.roster_target <= 0 then 'healthy'
    when coalesce(rc.roster_count, 0) < greatest(1, ceil(t.roster_target::numeric * 0.5)::integer) then 'critical'
    when coalesce(rc.roster_count, 0) < t.roster_target then 'thin'
    when coalesce(rc.roster_count, 0) = t.roster_target then 'full'
    when coalesce(rc.roster_count, 0) > t.roster_target + 2 then 'overloaded'
    else 'healthy'
  end as roster_health
from accessible_teams t
left join roster_counts rc on rc.team_id = t.id;

create view public.team_tournament_deadlines_v
with (security_invoker = true)
as
select
  t.club_id,
  t.id as team_id,
  t.team_name,
  trn.id as tournament_id,
  trn.name as tournament_name,
  tt.id as team_tournament_id,
  tt.status as tournament_status,
  td.deadline_type,
  td.due_at,
  case
    when td.status = 'completed' then 'complete'
    when td.due_at < now() then 'overdue'
    when td.due_at <= now() + interval '14 days' then 'due_soon'
    else 'upcoming'
  end as deadline_status,
  (td.due_at::date - current_date)::integer as days_until_due
from public.teams t
join public.team_tournaments tt
  on tt.team_id = t.id
 and tt.club_id = t.club_id
 and tt.deleted_at is null
join public.tournaments trn
  on trn.id = tt.tournament_id
 and trn.club_id = t.club_id
 and trn.deleted_at is null
join public.tournament_deadlines td
  on td.team_tournament_id = tt.id
 and td.club_id = t.club_id
 and td.deleted_at is null
where t.deleted_at is null
  and t.club_id = (select private.current_user_club_id())
  and (
    (select private.is_doc_or_club_manager())
    or (select private.is_team_staff(t.id))
  );

create view public.team_document_readiness_v
with (security_invoker = true)
as
with accessible_teams as (
  select t.*
  from public.teams t
  where t.deleted_at is null
    and t.club_id = (select private.current_user_club_id())
    and (
      (select private.is_doc_or_club_manager())
      or (select private.is_team_staff(t.id))
    )
),
requirements as (
  select
    t.club_id,
    t.id as team_id,
    t.team_name,
    dr.id as document_requirement_id,
    dr.owner_type,
    dr.document_type_id,
    dt.name as required_document_type,
    case
      when dt.name ilike 'US Club%' then 'US Club'
      when dt.name ilike 'USYS%' then 'USYS'
      else null
    end as governing_body
  from accessible_teams t
  join public.document_requirements dr
    on dr.club_id = t.club_id
   and dr.deleted_at is null
   and dr.is_required
   and dr.owner_type in ('player', 'staff', 'team')
   and (dr.team_id is null or dr.team_id = t.id)
   and (dr.age_group is null or dr.age_group = t.age_group)
   and (dr.team_level is null or dr.team_level = t.level)
  join public.document_types dt
    on dt.id = dr.document_type_id
   and dt.deleted_at is null
),
player_owners as (
  select distinct
    r.document_requirement_id,
    p.id as owner_id
  from requirements r
  join public.players p
    on r.owner_type = 'player'
   and p.club_id = r.club_id
   and p.home_team_id = r.team_id
   and p.deleted_at is null
   and p.status::text not in ('inactive', 'closed')
  union
  select distinct
    r.document_requirement_id,
    p.id as owner_id
  from requirements r
  join public.roster_assignments ra
    on r.owner_type = 'player'
   and ra.club_id = r.club_id
   and ra.team_id = r.team_id
   and ra.deleted_at is null
   and ra.assignment_type = 'home_team'
   and ra.is_home_team
   and (ra.start_date is null or ra.start_date <= current_date)
   and (ra.end_date is null or ra.end_date >= current_date)
  join public.players p
    on p.id = ra.player_id
   and p.club_id = r.club_id
   and p.deleted_at is null
   and p.status::text not in ('inactive', 'closed')
),
staff_owners as (
  select distinct
    r.document_requirement_id,
    ts.profile_id as owner_id
  from requirements r
  join public.team_staff ts
    on r.owner_type = 'staff'
   and ts.club_id = r.club_id
   and ts.team_id = r.team_id
   and ts.deleted_at is null
   and (ts.end_date is null or ts.end_date >= current_date)
  join public.profiles p
    on p.id = ts.profile_id
   and p.deleted_at is null
   and p.is_active
),
team_owners as (
  select
    r.document_requirement_id,
    r.team_id as owner_id
  from requirements r
  where r.owner_type = 'team'
),
owners as (
  select * from player_owners
  union
  select * from staff_owners
  union
  select * from team_owners
),
latest_documents as (
  select distinct on (d.owner_type, d.owner_id, d.document_type_id)
    d.owner_type,
    d.owner_id,
    d.document_type_id,
    d.status
  from public.documents d
  where d.deleted_at is null
  order by d.owner_type, d.owner_id, d.document_type_id, d.created_at desc
)
select
  r.club_id,
  r.team_id,
  r.team_name,
  r.required_document_type,
  r.governing_body,
  count(o.owner_id) filter (
    where coalesce(ld.status, 'missing') = 'missing'
  )::integer as missing_count,
  count(o.owner_id) filter (where ld.status = 'uploaded')::integer as uploaded_count,
  count(o.owner_id) filter (where ld.status = 'approved')::integer as approved_count,
  count(o.owner_id) filter (where ld.status = 'expired')::integer as expired_count,
  count(o.owner_id) filter (where ld.status = 'expiring_soon')::integer as expiring_soon_count,
  count(o.owner_id) filter (where ld.status = 'rejected')::integer as rejected_count
from requirements r
left join owners o on o.document_requirement_id = r.document_requirement_id
left join latest_documents ld
  on ld.owner_type = r.owner_type
 and ld.owner_id = o.owner_id
 and ld.document_type_id = r.document_type_id
group by
  r.club_id,
  r.team_id,
  r.team_name,
  r.required_document_type,
  r.governing_body;

create view public.player_document_status_v
with (security_invoker = true)
as
with accessible_players as (
  select
    p.*,
    t.team_name as home_team_name
  from public.players p
  left join public.teams t
    on t.id = p.home_team_id
   and t.deleted_at is null
  where p.deleted_at is null
    and p.club_id = (select private.current_user_club_id())
    and (
      (select private.is_doc_or_club_manager())
      or (select private.can_access_player(p.id))
    )
),
latest_player_documents as (
  select distinct on (d.owner_id, dt.name)
    d.owner_id as player_id,
    dt.name as document_type_name,
    d.status
  from public.documents d
  join public.document_types dt
    on dt.id = d.document_type_id
   and dt.deleted_at is null
  where d.owner_type = 'player'
    and d.deleted_at is null
  order by d.owner_id, dt.name, d.created_at desc
)
select
  p.club_id,
  p.id as player_id,
  concat_ws(' ', p.first_name, p.last_name) as player_name,
  p.home_team_id,
  p.home_team_name,
  s.us_club_card_status,
  s.usys_card_status,
  s.birth_certificate_status,
  s.medical_release_status,
  s.liability_waiver_status,
  (
    case when s.us_club_card_status in ('missing', 'rejected', 'expired') then 1 else 0 end
    + case when s.usys_card_status in ('missing', 'rejected', 'expired') then 1 else 0 end
    + case when s.birth_certificate_status in ('missing', 'rejected', 'expired') then 1 else 0 end
    + case when s.medical_release_status in ('missing', 'rejected', 'expired') then 1 else 0 end
    + case when s.liability_waiver_status in ('missing', 'rejected', 'expired') then 1 else 0 end
  ) as missing_required_count,
  case
    when s.us_club_card_status in ('missing', 'rejected', 'expired')
      or s.usys_card_status in ('missing', 'rejected', 'expired')
      or s.birth_certificate_status in ('missing', 'rejected', 'expired')
      or s.medical_release_status in ('missing', 'rejected', 'expired')
      or s.liability_waiver_status in ('missing', 'rejected', 'expired')
      then 'blocked'
    when s.us_club_card_status = 'uploaded'
      or s.usys_card_status = 'uploaded'
      or s.birth_certificate_status = 'uploaded'
      or s.medical_release_status = 'uploaded'
      or s.liability_waiver_status = 'uploaded'
      then 'needs_review'
    when s.us_club_card_status = 'expiring_soon'
      or s.usys_card_status = 'expiring_soon'
      or s.birth_certificate_status = 'expiring_soon'
      or s.medical_release_status = 'expiring_soon'
      or s.liability_waiver_status = 'expiring_soon'
      then 'expiring_soon'
    else 'compliant'
  end as player_compliance_status
from accessible_players p
cross join lateral (
  select
    coalesce((select lpd.status from latest_player_documents lpd where lpd.player_id = p.id and lpd.document_type_name = 'US Club Player Card'), 'missing') as us_club_card_status,
    coalesce((select lpd.status from latest_player_documents lpd where lpd.player_id = p.id and lpd.document_type_name = 'USYS Player Card'), 'missing') as usys_card_status,
    coalesce((select lpd.status from latest_player_documents lpd where lpd.player_id = p.id and lpd.document_type_name = 'Birth Certificate'), 'missing') as birth_certificate_status,
    coalesce((select lpd.status from latest_player_documents lpd where lpd.player_id = p.id and lpd.document_type_name = 'Medical Release'), 'missing') as medical_release_status,
    coalesce((select lpd.status from latest_player_documents lpd where lpd.player_id = p.id and lpd.document_type_name = 'Liability Waiver'), 'missing') as liability_waiver_status
) s;

create view public.staff_compliance_status_v
with (security_invoker = true)
as
with accessible_staff as (
  select distinct p.*
  from public.profiles p
  left join public.team_staff ts
    on ts.profile_id = p.id
   and ts.deleted_at is null
   and (ts.end_date is null or ts.end_date >= current_date)
  where p.deleted_at is null
    and p.is_active
    and p.club_id = (select private.current_user_club_id())
    and p.role in ('doc', 'club_manager', 'head_coach', 'assistant_coach', 'team_manager')
    and (
      (select private.is_doc_or_club_manager())
      or p.id = (select private.current_user_profile_id())
      or exists (
        select 1
        from public.team_staff mine
        where mine.club_id = p.club_id
          and mine.team_id = ts.team_id
          and mine.profile_id = (select private.current_user_profile_id())
          and mine.deleted_at is null
          and (mine.end_date is null or mine.end_date >= current_date)
      )
    )
),
assigned_team_counts as (
  select
    ts.profile_id,
    count(distinct ts.team_id)::integer as assigned_team_count
  from public.team_staff ts
  where ts.deleted_at is null
    and (ts.end_date is null or ts.end_date >= current_date)
  group by ts.profile_id
),
latest_staff_documents as (
  select distinct on (d.owner_id, dt.name)
    d.owner_id as profile_id,
    dt.name as document_type_name,
    d.status
  from public.documents d
  join public.document_types dt
    on dt.id = d.document_type_id
   and dt.deleted_at is null
  where d.owner_type = 'staff'
    and d.deleted_at is null
  order by d.owner_id, dt.name, d.created_at desc
)
select
  p.club_id,
  p.id as profile_id,
  concat_ws(' ', p.first_name, p.last_name) as staff_name,
  p.role,
  coalesce(atc.assigned_team_count, 0) as assigned_team_count,
  s.us_club_card_status,
  s.usys_card_status,
  s.safesport_status,
  s.background_check_status,
  s.coaching_license_status,
  (
    case when s.us_club_card_status in ('missing', 'rejected', 'expired') then 1 else 0 end
    + case when s.usys_card_status in ('missing', 'rejected', 'expired') then 1 else 0 end
    + case when s.safesport_status in ('missing', 'rejected', 'expired') then 1 else 0 end
    + case when s.background_check_status in ('missing', 'rejected', 'expired') then 1 else 0 end
    + case when s.coaching_license_status in ('missing', 'rejected', 'expired') then 1 else 0 end
  ) as missing_required_count,
  case
    when s.us_club_card_status in ('missing', 'rejected', 'expired')
      or s.usys_card_status in ('missing', 'rejected', 'expired')
      or s.safesport_status in ('missing', 'rejected', 'expired')
      or s.background_check_status in ('missing', 'rejected', 'expired')
      or s.coaching_license_status in ('missing', 'rejected', 'expired')
      then 'blocked'
    when s.us_club_card_status = 'uploaded'
      or s.usys_card_status = 'uploaded'
      or s.safesport_status = 'uploaded'
      or s.background_check_status = 'uploaded'
      or s.coaching_license_status = 'uploaded'
      then 'needs_review'
    when s.us_club_card_status = 'expiring_soon'
      or s.usys_card_status = 'expiring_soon'
      or s.safesport_status = 'expiring_soon'
      or s.background_check_status = 'expiring_soon'
      or s.coaching_license_status = 'expiring_soon'
      then 'expiring_soon'
    else 'compliant'
  end as staff_compliance_status
from accessible_staff p
left join assigned_team_counts atc on atc.profile_id = p.id
cross join lateral (
  select
    coalesce((select lsd.status from latest_staff_documents lsd where lsd.profile_id = p.id and lsd.document_type_name = 'US Club Coach Card'), 'missing') as us_club_card_status,
    coalesce((select lsd.status from latest_staff_documents lsd where lsd.profile_id = p.id and lsd.document_type_name = 'USYS Coach Card'), 'missing') as usys_card_status,
    coalesce((select lsd.status from latest_staff_documents lsd where lsd.profile_id = p.id and lsd.document_type_name = 'SafeSport'), 'missing') as safesport_status,
    coalesce((select lsd.status from latest_staff_documents lsd where lsd.profile_id = p.id and lsd.document_type_name = 'Background Check'), 'missing') as background_check_status,
    coalesce((select lsd.status from latest_staff_documents lsd where lsd.profile_id = p.id and lsd.document_type_name = 'Coaching License'), 'missing') as coaching_license_status
) s;

create view public.pipeline_risk_v
with (security_invoker = true)
as
select
  i.club_id,
  i.id as inquiry_id,
  concat_ws(' ', i.player_first_name, i.player_last_name) as player_name,
  i.interested_team_id,
  t.team_name as interested_team_name,
  i.pipeline_stage,
  i.priority,
  concat_ws(' ', coach.first_name, coach.last_name) as assigned_coach_name,
  concat_ws(' ', manager.first_name, manager.last_name) as assigned_manager_name,
  concat_ws(' ', admin.first_name, admin.last_name) as assigned_admin_name,
  i.next_action,
  i.next_action_due_at,
  (current_date - i.created_at::date)::integer as days_since_created,
  case
    when i.last_contacted_at is null then null
    else (current_date - i.last_contacted_at::date)::integer
  end as days_since_last_contact,
  case
    when i.pipeline_stage = 'ready_to_roster' then 'ready_to_roster'
    when i.next_action_due_at is not null and i.next_action_due_at < now() then 'overdue'
    when i.assigned_coach_id is null and i.assigned_manager_id is null and i.assigned_admin_id is null then 'unassigned'
    when i.last_contacted_at is null and i.created_at < now() - interval '7 days' then 'waiting'
    else 'normal'
  end as risk_status
from public.player_inquiries i
left join public.teams t on t.id = i.interested_team_id and t.deleted_at is null
left join public.profiles coach on coach.id = i.assigned_coach_id and coach.deleted_at is null
left join public.profiles manager on manager.id = i.assigned_manager_id and manager.deleted_at is null
left join public.profiles admin on admin.id = i.assigned_admin_id and admin.deleted_at is null
where i.deleted_at is null
  and i.club_id = (select private.current_user_club_id())
  and (
    (select private.is_doc_or_club_manager())
    or (select private.current_user_profile_id()) in (i.assigned_coach_id, i.assigned_manager_id, i.assigned_admin_id)
    or (i.interested_team_id is not null and (select private.is_team_staff(i.interested_team_id)))
  );

create view public.doc_team_readiness_v
with (security_invoker = true)
as
with accessible_teams as (
  select t.*
  from public.teams t
  where t.deleted_at is null
    and t.club_id = (select private.current_user_club_id())
    and (
      (select private.is_doc_or_club_manager())
      or (select private.is_team_staff(t.id))
    )
)
select
  t.club_id,
  t.season_id,
  t.id as team_id,
  t.team_name,
  t.age_group,
  t.gender,
  t.team_format,
  t.level,
  t.team_status,
  t.roster_target,
  coalesce(rh.roster_count, 0) as roster_count,
  coalesce(rh.needed_players, greatest(coalesce(t.roster_target, 0), 0)) as needed_players,
  coalesce(rh.roster_health, 'healthy') as roster_health,
  staff.head_coach_name,
  staff.manager_name,
  case
    when staff.head_coach_name is null and staff.manager_name is null then 'critical'
    when staff.head_coach_name is null then 'needs_head_coach'
    when staff.manager_name is null then 'needs_manager'
    else 'ready'
  end as staff_status,
  leagues.primary_league_name,
  leagues.secondary_league_name,
  coalesce(leagues.league_count, 0) as league_count,
  case
    when coalesce(leagues.league_count, 0) = 0 then 'no_league'
    when leagues.primary_league_name is null then 'missing_primary'
    else 'ready'
  end as league_status,
  coalesce(tournaments.upcoming_tournament_count, 0) as upcoming_tournament_count,
  deadlines.next_tournament_name,
  deadlines.next_tournament_deadline_type,
  deadlines.next_tournament_deadline_due_at,
  coalesce(docs.missing_document_count, 0) as missing_document_count,
  coalesce(docs.us_club_missing_count, 0) as us_club_missing_count,
  coalesce(docs.usys_missing_count, 0) as usys_missing_count,
  case
    when coalesce(rh.roster_health, 'healthy') = 'critical'
      or (staff.head_coach_name is null and staff.manager_name is null)
      then 'critical'
    when staff.head_coach_name is null or staff.manager_name is null then 'needs_staff'
    when coalesce(rh.needed_players, 0) > 0 then 'needs_roster'
    when coalesce(leagues.league_count, 0) = 0 or leagues.primary_league_name is null then 'needs_league'
    when coalesce(docs.missing_document_count, 0) > 0 then 'needs_documents'
    else 'ready'
  end as competition_readiness
from accessible_teams t
left join public.roster_health_v rh on rh.team_id = t.id
left join lateral (
  select
    string_agg(distinct concat_ws(' ', p.first_name, p.last_name), ', ' order by concat_ws(' ', p.first_name, p.last_name)) filter (where ts.role = 'head_coach') as head_coach_name,
    string_agg(distinct concat_ws(' ', p.first_name, p.last_name), ', ' order by concat_ws(' ', p.first_name, p.last_name)) filter (where ts.role = 'team_manager') as manager_name
  from public.team_staff ts
  join public.profiles p
    on p.id = ts.profile_id
   and p.deleted_at is null
   and p.is_active
  where ts.club_id = t.club_id
    and ts.team_id = t.id
    and ts.deleted_at is null
    and (ts.end_date is null or ts.end_date >= current_date)
) staff on true
left join lateral (
  select
    string_agg(distinct l.name, ', ' order by l.name) filter (where tl.league_role = 'primary') as primary_league_name,
    string_agg(distinct l.name, ', ' order by l.name) filter (where tl.league_role = 'secondary') as secondary_league_name,
    count(distinct tl.id)::integer as league_count
  from public.team_leagues tl
  join public.leagues l
    on l.id = tl.league_id
   and l.deleted_at is null
  where tl.club_id = t.club_id
    and tl.team_id = t.id
    and tl.deleted_at is null
) leagues on true
left join lateral (
  select count(distinct tt.id)::integer as upcoming_tournament_count
  from public.team_tournaments tt
  join public.tournaments trn
    on trn.id = tt.tournament_id
   and trn.deleted_at is null
  where tt.club_id = t.club_id
    and tt.team_id = t.id
    and tt.deleted_at is null
    and trn.end_date >= current_date
) tournaments on true
left join lateral (
  select
    ttd.tournament_name as next_tournament_name,
    ttd.deadline_type as next_tournament_deadline_type,
    ttd.due_at as next_tournament_deadline_due_at
  from public.team_tournament_deadlines_v ttd
  where ttd.team_id = t.id
    and ttd.deadline_status <> 'complete'
  order by ttd.due_at
  limit 1
) deadlines on true
left join lateral (
  select
    sum(tdr.missing_count + tdr.expired_count + tdr.rejected_count)::integer as missing_document_count,
    sum(tdr.missing_count + tdr.expired_count + tdr.rejected_count) filter (where tdr.governing_body = 'US Club')::integer as us_club_missing_count,
    sum(tdr.missing_count + tdr.expired_count + tdr.rejected_count) filter (where tdr.governing_body = 'USYS')::integer as usys_missing_count
  from public.team_document_readiness_v tdr
  where tdr.team_id = t.id
) docs on true;

create view public.team_competition_readiness_v
with (security_invoker = true)
as
select
  dtr.team_id,
  dtr.club_id,
  dtr.team_name,
  dtr.season_id,
  dtr.roster_health as roster_readiness,
  dtr.league_status as league_readiness,
  case
    when coalesce(deadline_stats.overdue_count, 0) > 0 then 'overdue_deadlines'
    when coalesce(deadline_stats.due_soon_count, 0) > 0 then 'deadlines_due_soon'
    when dtr.upcoming_tournament_count > 0 then 'scheduled'
    else 'no_tournament'
  end as tournament_readiness,
  case
    when dtr.missing_document_count > 0 then 'needs_documents'
    else 'ready'
  end as document_readiness,
  dtr.staff_status as staff_readiness,
  dtr.competition_readiness as overall_readiness,
  array_remove(array[
    case when dtr.roster_health in ('critical', 'thin') then 'roster' end,
    case when dtr.staff_status <> 'ready' then 'staff' end,
    case when dtr.league_status <> 'ready' then 'league' end,
    case when dtr.missing_document_count > 0 then 'documents' end,
    case when coalesce(deadline_stats.overdue_count, 0) > 0 then 'overdue_deadlines' end,
    case when dtr.upcoming_tournament_count = 0 then 'tournament' end
  ], null) as blockers
from public.doc_team_readiness_v dtr
left join lateral (
  select
    count(*) filter (where ttd.deadline_status = 'overdue')::integer as overdue_count,
    count(*) filter (where ttd.deadline_status = 'due_soon')::integer as due_soon_count
  from public.team_tournament_deadlines_v ttd
  where ttd.team_id = dtr.team_id
) deadline_stats on true;

create view public.doc_today_readiness_v
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
    count(*) filter (
      where ttd.deadline_status in ('due_soon', 'upcoming')
        and ttd.due_at <= now() + interval '30 days'
    )::integer as upcoming_tournament_deadlines_count,
    (
      count(*) filter (
        where ttd.deadline_type = 'roster_upload'
          and ttd.deadline_status in ('overdue', 'due_soon', 'upcoming')
          and ttd.due_at <= now() + interval '30 days'
      )
      + count(*) filter (
        where tl.roster_upload_deadline is not null
          and tl.roster_upload_deadline <= now() + interval '30 days'
      )
    )::integer as roster_uploads_due_count
  from public.team_tournament_deadlines_v ttd
  left join public.team_leagues tl
    on tl.club_id = c.id
   and tl.deleted_at is null
   and tl.roster_upload_deadline is not null
   and tl.roster_upload_deadline <= now() + interval '30 days'
  where ttd.club_id = c.id
) deadline_counts on true
where c.deleted_at is null
  and c.id = (select private.current_user_club_id())
  and (select private.is_doc_or_club_manager());

revoke all on
  public.doc_today_readiness_v,
  public.doc_team_readiness_v,
  public.team_competition_readiness_v,
  public.team_tournament_deadlines_v,
  public.team_document_readiness_v,
  public.player_document_status_v,
  public.staff_compliance_status_v,
  public.pipeline_risk_v,
  public.roster_health_v
from public, anon;

grant select on
  public.doc_today_readiness_v,
  public.doc_team_readiness_v,
  public.team_competition_readiness_v,
  public.team_tournament_deadlines_v,
  public.team_document_readiness_v,
  public.player_document_status_v,
  public.staff_compliance_status_v,
  public.pipeline_risk_v,
  public.roster_health_v
to authenticated, service_role;
