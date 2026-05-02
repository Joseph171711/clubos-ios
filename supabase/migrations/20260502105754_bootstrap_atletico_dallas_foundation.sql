-- Bootstrap the first real ClubOS club and active season.
-- Founding DOC profile creation is intentionally handled by
-- supabase/scripts/bootstrap_founding_doc.sql after the first Supabase Auth
-- user exists. At migration time, auth.users is empty, and manually inserting
-- Auth rows is not a safe bootstrap path.

alter table public.clubs
  add column if not exists status text not null default 'active';

do $$
begin
  if not exists (
    select 1
    from pg_constraint
    where conrelid = 'public.clubs'::regclass
      and conname = 'clubs_status_valid'
  ) then
    alter table public.clubs
      add constraint clubs_status_valid
      check (status in ('active', 'inactive', 'archived'));
  end if;
end;
$$;

do $$
declare
  v_club_id uuid;
  v_season_id uuid;
  v_team_id uuid;
  v_head_coach_profile_id uuid;
  v_team_manager_profile_id uuid;
  v_inquiry_id uuid;
  v_player_id uuid;
  v_birth_certificate_type_id uuid;
begin
  insert into public.clubs (
    name,
    slug,
    status,
    timezone,
    deleted_at
  )
  values (
    'Atletico Dallas',
    'atletico-dallas',
    'active',
    'America/Chicago',
    null
  )
  on conflict (slug) do update
  set
    name = excluded.name,
    status = excluded.status,
    timezone = excluded.timezone,
    deleted_at = null,
    updated_at = now()
  returning id into v_club_id;

  insert into public.seasons (
    club_id,
    name,
    start_date,
    end_date,
    is_active,
    deleted_at
  )
  values (
    v_club_id,
    '2026-2027',
    date '2026-08-01',
    date '2027-07-31',
    true,
    null
  )
  on conflict (club_id, name) do update
  set
    start_date = excluded.start_date,
    end_date = excluded.end_date,
    is_active = excluded.is_active,
    deleted_at = null,
    updated_at = now()
  returning id into v_season_id;

  update public.seasons
  set
    is_active = false,
    updated_at = now()
  where club_id = v_club_id
    and id <> v_season_id
    and is_active
    and deleted_at is null;

  insert into public.teams (
    club_id,
    season_id,
    team_name,
    age_group,
    birth_year,
    gender,
    team_format,
    level,
    roster_target,
    training_location,
    training_days,
    team_status,
    deleted_at
  )
  values (
    v_club_id,
    v_season_id,
    'QA U12 Boys 9v9',
    'U12',
    2015,
    'boys',
    '9v9',
    'select',
    14,
    'Atletico Dallas QA Training Field',
    array['Tuesday', 'Thursday'],
    'active',
    null
  )
  on conflict (club_id, season_id, team_name) do update
  set
    age_group = excluded.age_group,
    birth_year = excluded.birth_year,
    gender = excluded.gender,
    team_format = excluded.team_format,
    level = excluded.level,
    roster_target = excluded.roster_target,
    training_location = excluded.training_location,
    training_days = excluded.training_days,
    team_status = excluded.team_status,
    deleted_at = null,
    updated_at = now()
  returning id into v_team_id;

  select id
  into v_head_coach_profile_id
  from public.profiles
  where club_id = v_club_id
    and lower(email) = 'qa.headcoach@clubos.invalid'
    and deleted_at is null
  limit 1;

  if v_head_coach_profile_id is null then
    insert into public.profiles (
      club_id,
      role,
      first_name,
      last_name,
      email,
      is_active
    )
    values (
      v_club_id,
      'head_coach',
      'QA',
      'Head Coach',
      'qa.headcoach@clubos.invalid',
      true
    )
    returning id into v_head_coach_profile_id;
  else
    update public.profiles
    set
      role = 'head_coach',
      first_name = 'QA',
      last_name = 'Head Coach',
      is_active = true,
      updated_at = now()
    where id = v_head_coach_profile_id;
  end if;

  select id
  into v_team_manager_profile_id
  from public.profiles
  where club_id = v_club_id
    and lower(email) = 'qa.teammanager@clubos.invalid'
    and deleted_at is null
  limit 1;

  if v_team_manager_profile_id is null then
    insert into public.profiles (
      club_id,
      role,
      first_name,
      last_name,
      email,
      is_active
    )
    values (
      v_club_id,
      'team_manager',
      'QA',
      'Team Manager',
      'qa.teammanager@clubos.invalid',
      true
    )
    returning id into v_team_manager_profile_id;
  else
    update public.profiles
    set
      role = 'team_manager',
      first_name = 'QA',
      last_name = 'Team Manager',
      is_active = true,
      updated_at = now()
    where id = v_team_manager_profile_id;
  end if;

  if not exists (
    select 1
    from public.team_staff
    where club_id = v_club_id
      and team_id = v_team_id
      and profile_id = v_head_coach_profile_id
      and role = 'head_coach'
      and deleted_at is null
  ) then
    insert into public.team_staff (
      club_id,
      team_id,
      profile_id,
      role,
      start_date
    )
    values (
      v_club_id,
      v_team_id,
      v_head_coach_profile_id,
      'head_coach',
      date '2026-08-01'
    );
  end if;

  if not exists (
    select 1
    from public.team_staff
    where club_id = v_club_id
      and team_id = v_team_id
      and profile_id = v_team_manager_profile_id
      and role = 'team_manager'
      and deleted_at is null
  ) then
    insert into public.team_staff (
      club_id,
      team_id,
      profile_id,
      role,
      start_date
    )
    values (
      v_club_id,
      v_team_id,
      v_team_manager_profile_id,
      'team_manager',
      date '2026-08-01'
    );
  end if;

  select id
  into v_inquiry_id
  from public.player_inquiries
  where club_id = v_club_id
    and parent_guardian_email = 'qa.parent.inquiry@clubos.invalid'
    and player_first_name = 'QA'
    and player_last_name = 'Inquiry'
    and deleted_at is null
  limit 1;

  if v_inquiry_id is null then
    insert into public.player_inquiries (
      club_id,
      player_first_name,
      player_last_name,
      preferred_name,
      birth_year,
      gender,
      current_club,
      positions,
      experience_level,
      interested_team_id,
      interested_age_group,
      source,
      parent_guardian_name,
      parent_guardian_phone,
      parent_guardian_email,
      preferred_contact_method,
      assigned_coach_id,
      assigned_manager_id,
      pipeline_stage,
      priority,
      next_action,
      next_action_due_at,
      notes
    )
    values (
      v_club_id,
      'QA',
      'Inquiry',
      'QA Inquiry',
      2015,
      'boys',
      'QA Current Club',
      array['midfielder'],
      'competitive',
      v_team_id,
      'U12',
      'qa_fixture',
      'QA Inquiry Parent',
      '555-0100',
      'qa.parent.inquiry@clubos.invalid',
      'email',
      v_head_coach_profile_id,
      v_team_manager_profile_id,
      'assigned',
      3,
      'QA fixture: complete first contact',
      timestamptz '2026-08-05 15:00:00+00',
      'QA fixture for RLS and Rork readiness testing.'
    )
    returning id into v_inquiry_id;
  else
    update public.player_inquiries
    set
      interested_team_id = v_team_id,
      assigned_coach_id = v_head_coach_profile_id,
      assigned_manager_id = v_team_manager_profile_id,
      pipeline_stage = 'assigned',
      next_action = 'QA fixture: complete first contact',
      next_action_due_at = timestamptz '2026-08-05 15:00:00+00',
      updated_at = now()
    where id = v_inquiry_id;
  end if;

  select id
  into v_player_id
  from public.players
  where club_id = v_club_id
    and parent_email = 'qa.parent.rostered@clubos.invalid'
    and first_name = 'QA'
    and last_name = 'Rostered'
    and deleted_at is null
  limit 1;

  if v_player_id is null then
    insert into public.players (
      club_id,
      first_name,
      last_name,
      preferred_name,
      date_of_birth,
      true_age_group,
      playing_age_group,
      gender,
      positions,
      jersey_number,
      dominant_foot,
      home_team_id,
      status,
      parent_name,
      parent_phone,
      parent_email,
      emergency_contact_name,
      emergency_contact_phone,
      notes
    )
    values (
      v_club_id,
      'QA',
      'Rostered',
      'QA Rostered',
      date '2015-05-15',
      'U12',
      'U12',
      'boys',
      array['defender'],
      12,
      'right',
      v_team_id,
      'rostered',
      'QA Rostered Parent',
      '555-0101',
      'qa.parent.rostered@clubos.invalid',
      'QA Emergency Contact',
      '555-0102',
      'QA fixture for roster and document readiness testing.'
    )
    returning id into v_player_id;
  else
    update public.players
    set
      home_team_id = v_team_id,
      status = 'rostered',
      true_age_group = 'U12',
      playing_age_group = 'U12',
      jersey_number = 12,
      updated_at = now()
    where id = v_player_id;
  end if;

  if not exists (
    select 1
    from public.roster_assignments
    where club_id = v_club_id
      and season_id = v_season_id
      and player_id = v_player_id
      and team_id = v_team_id
      and assignment_type = 'home_team'
      and deleted_at is null
  ) then
    insert into public.roster_assignments (
      club_id,
      season_id,
      player_id,
      team_id,
      assignment_type,
      is_home_team,
      eligibility_notes,
      start_date
    )
    values (
      v_club_id,
      v_season_id,
      v_player_id,
      v_team_id,
      'home_team',
      true,
      'QA home-team roster assignment.',
      date '2026-08-01'
    );
  end if;

  select id
  into v_birth_certificate_type_id
  from public.document_types
  where club_id is null
    and name = 'Birth Certificate'
    and deleted_at is null
  limit 1;

  if v_birth_certificate_type_id is null then
    raise exception 'Default Birth Certificate document type is missing';
  end if;

  if not exists (
    select 1
    from public.document_requirements
    where club_id = v_club_id
      and document_type_id = v_birth_certificate_type_id
      and owner_type = 'player'
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
      v_birth_certificate_type_id,
      'player',
      'U12',
      'select',
      v_team_id,
      true,
      timestamptz '2026-08-15 15:00:00+00',
      'QA fixture requirement for Rork document workflow testing.'
    );
  end if;
end;
$$;
