begin;

create extension if not exists pgcrypto;

create schema if not exists private;
revoke all on schema private from public;
grant usage on schema private to authenticated, service_role;

do $$
begin
  create type public.user_role as enum (
    'doc',
    'club_manager',
    'head_coach',
    'assistant_coach',
    'team_manager',
    'parent',
    'player'
  );
exception when duplicate_object then null;
end $$;

do $$
begin
  create type public.player_status as enum (
    'inquiry',
    'prospect',
    'trialist',
    'offered',
    'registered',
    'rostered',
    'inactive',
    'closed'
  );
exception when duplicate_object then null;
end $$;

do $$
begin
  create type public.roster_assignment_type as enum (
    'home_team',
    'sister_team',
    'guest_player',
    'training_only'
  );
exception when duplicate_object then null;
end $$;

do $$
begin
  create type public.league_role as enum ('primary', 'secondary', 'other');
exception when duplicate_object then null;
end $$;

do $$
begin
  create type public.match_status as enum ('scheduled', 'completed', 'canceled', 'postponed');
exception when duplicate_object then null;
end $$;

do $$
begin
  create type public.match_roster_role as enum ('regular', 'guest', 'unavailable');
exception when duplicate_object then null;
end $$;

do $$
begin
  create type public.tournament_status as enum (
    'projected',
    'applied',
    'accepted',
    'paid',
    'roster_uploaded',
    'checked_in',
    'completed'
  );
exception when duplicate_object then null;
end $$;

do $$
begin
  create type public.tournament_deadline_type as enum (
    'registration',
    'payment',
    'roster_upload',
    'check_in',
    'hotel',
    'other'
  );
exception when duplicate_object then null;
end $$;

do $$
begin
  create type public.document_owner_type as enum (
    'player',
    'staff',
    'team',
    'match',
    'tournament',
    'inquiry'
  );
exception when duplicate_object then null;
end $$;

create table public.team_formats (
  id text primary key,
  label text not null,
  sort_order integer not null unique,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table public.team_genders (
  id text primary key,
  label text not null,
  sort_order integer not null unique,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table public.team_levels (
  id text primary key,
  label text not null,
  sort_order integer not null unique,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table public.age_groups (
  id text primary key,
  label text not null,
  sort_order integer not null unique,
  min_age integer not null,
  max_age integer not null,
  eligible_format_ids text[] not null default '{}',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint age_groups_valid_age_range check (min_age <= max_age)
);

create table public.pipeline_stages (
  id text primary key,
  label text not null,
  sort_order integer not null unique,
  is_terminal boolean not null default false,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table public.task_statuses (
  id text primary key,
  label text not null,
  sort_order integer not null unique,
  is_terminal boolean not null default false,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table public.document_statuses (
  id text primary key,
  label text not null,
  sort_order integer not null unique,
  is_terminal boolean not null default false,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table public.clubs (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  slug text not null,
  legal_name text,
  timezone text not null default 'America/Chicago',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  deleted_at timestamptz,
  constraint clubs_slug_unique unique (slug)
);

create table public.seasons (
  id uuid primary key default gen_random_uuid(),
  club_id uuid not null references public.clubs(id) on delete restrict,
  name text not null,
  start_date date not null,
  end_date date not null,
  is_active boolean not null default false,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  deleted_at timestamptz,
  constraint seasons_valid_dates check (start_date <= end_date),
  constraint seasons_club_name_unique unique (club_id, name)
);

create table public.profiles (
  id uuid primary key default gen_random_uuid(),
  user_id uuid unique references auth.users(id) on delete set null,
  club_id uuid not null references public.clubs(id) on delete restrict,
  role public.user_role not null,
  first_name text not null,
  last_name text not null,
  email text,
  phone text,
  photo_url text,
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  deleted_at timestamptz
);

create table public.teams (
  id uuid primary key default gen_random_uuid(),
  club_id uuid not null references public.clubs(id) on delete restrict,
  season_id uuid not null references public.seasons(id) on delete restrict,
  team_name text not null,
  age_group text not null references public.age_groups(id),
  birth_year integer,
  gender text not null references public.team_genders(id),
  team_format text not null references public.team_formats(id),
  level text not null references public.team_levels(id),
  roster_target integer,
  training_location text,
  training_days text[] not null default '{}',
  team_status text not null default 'active',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  deleted_at timestamptz,
  constraint teams_roster_target_positive check (roster_target is null or roster_target > 0),
  constraint teams_status_valid check (team_status in ('forming', 'active', 'inactive', 'archived')),
  constraint teams_club_season_name_unique unique (club_id, season_id, team_name)
);

create table public.team_staff (
  id uuid primary key default gen_random_uuid(),
  club_id uuid not null references public.clubs(id) on delete restrict,
  team_id uuid not null references public.teams(id) on delete cascade,
  profile_id uuid not null references public.profiles(id) on delete cascade,
  role public.user_role not null,
  start_date date,
  end_date date,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  deleted_at timestamptz,
  constraint team_staff_role_valid check (role in ('head_coach', 'assistant_coach', 'team_manager')),
  constraint team_staff_dates_valid check (end_date is null or start_date is null or start_date <= end_date)
);

create table public.players (
  id uuid primary key default gen_random_uuid(),
  club_id uuid not null references public.clubs(id) on delete restrict,
  first_name text not null,
  last_name text not null,
  preferred_name text,
  photo_url text,
  date_of_birth date,
  true_age_group text references public.age_groups(id),
  playing_age_group text references public.age_groups(id),
  gender text not null references public.team_genders(id),
  positions text[] not null default '{}',
  jersey_number integer,
  dominant_foot text,
  home_team_id uuid references public.teams(id) on delete set null,
  status public.player_status not null default 'registered',
  parent_profile_id uuid references public.profiles(id) on delete set null,
  player_profile_id uuid references public.profiles(id) on delete set null,
  parent_name text,
  parent_phone text,
  parent_email text,
  emergency_contact_name text,
  emergency_contact_phone text,
  medical_notes text,
  notes text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  deleted_at timestamptz,
  constraint players_jersey_positive check (jersey_number is null or jersey_number > 0),
  constraint players_dominant_foot_valid check (dominant_foot is null or dominant_foot in ('left', 'right', 'both'))
);

create table public.roster_assignments (
  id uuid primary key default gen_random_uuid(),
  club_id uuid not null references public.clubs(id) on delete restrict,
  season_id uuid not null references public.seasons(id) on delete restrict,
  player_id uuid not null references public.players(id) on delete cascade,
  team_id uuid not null references public.teams(id) on delete cascade,
  assignment_type public.roster_assignment_type not null,
  is_home_team boolean not null default false,
  eligibility_notes text,
  start_date date,
  end_date date,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  deleted_at timestamptz,
  constraint roster_assignments_dates_valid check (end_date is null or start_date is null or start_date <= end_date),
  constraint roster_assignments_home_team_consistent check (
    (assignment_type = 'home_team' and is_home_team)
    or (assignment_type <> 'home_team' and not is_home_team)
  )
);

create table public.player_inquiries (
  id uuid primary key default gen_random_uuid(),
  club_id uuid not null references public.clubs(id) on delete restrict,
  player_first_name text not null,
  player_last_name text not null,
  preferred_name text,
  date_of_birth date,
  birth_year integer,
  gender text not null references public.team_genders(id),
  current_club text,
  positions text[] not null default '{}',
  experience_level text,
  interested_team_id uuid references public.teams(id) on delete set null,
  interested_age_group text references public.age_groups(id),
  source text,
  referred_by text,
  parent_guardian_name text not null,
  parent_guardian_phone text,
  parent_guardian_email text,
  preferred_contact_method text,
  assigned_coach_id uuid references public.profiles(id) on delete set null,
  assigned_manager_id uuid references public.profiles(id) on delete set null,
  assigned_admin_id uuid references public.profiles(id) on delete set null,
  pipeline_stage text not null default 'new' references public.pipeline_stages(id),
  priority smallint not null default 3,
  next_action text,
  next_action_due_at timestamptz,
  last_contacted_at timestamptz,
  trial_date date,
  notes text,
  converted_player_id uuid references public.players(id) on delete set null,
  converted_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  deleted_at timestamptz,
  constraint player_inquiries_birth_present check (date_of_birth is not null or birth_year is not null),
  constraint player_inquiries_priority_valid check (priority between 1 and 5),
  constraint player_inquiries_contact_method_valid check (
    preferred_contact_method is null or preferred_contact_method in ('phone', 'email', 'text')
  )
);

create table public.pipeline_tasks (
  id uuid primary key default gen_random_uuid(),
  club_id uuid not null references public.clubs(id) on delete restrict,
  inquiry_id uuid not null references public.player_inquiries(id) on delete cascade,
  assigned_to_profile_id uuid references public.profiles(id) on delete set null,
  task_type text not null,
  title text not null,
  description text,
  due_at timestamptz,
  completed_at timestamptz,
  status text not null default 'open' references public.task_statuses(id),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  deleted_at timestamptz
);

create table public.trial_events (
  id uuid primary key default gen_random_uuid(),
  club_id uuid not null references public.clubs(id) on delete restrict,
  inquiry_id uuid not null references public.player_inquiries(id) on delete cascade,
  team_id uuid references public.teams(id) on delete set null,
  assigned_coach_id uuid references public.profiles(id) on delete set null,
  trial_starts_at timestamptz not null,
  trial_ends_at timestamptz,
  location text,
  field_number text,
  status text not null default 'scheduled',
  notes text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  deleted_at timestamptz,
  constraint trial_events_status_valid check (status in ('scheduled', 'completed', 'canceled', 'no_show')),
  constraint trial_events_dates_valid check (trial_ends_at is null or trial_starts_at <= trial_ends_at)
);

create table public.trial_evaluations (
  id uuid primary key default gen_random_uuid(),
  club_id uuid not null references public.clubs(id) on delete restrict,
  trial_event_id uuid not null references public.trial_events(id) on delete cascade,
  inquiry_id uuid not null references public.player_inquiries(id) on delete cascade,
  evaluator_profile_id uuid not null references public.profiles(id) on delete restrict,
  technical_score smallint,
  tactical_score smallint,
  physical_score smallint,
  coachability_score smallint,
  recommendation text,
  recommended_pipeline_stage text references public.pipeline_stages(id),
  notes text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  deleted_at timestamptz,
  constraint trial_evaluations_scores_valid check (
    (technical_score is null or technical_score between 1 and 5)
    and (tactical_score is null or tactical_score between 1 and 5)
    and (physical_score is null or physical_score between 1 and 5)
    and (coachability_score is null or coachability_score between 1 and 5)
  )
);

create table public.pipeline_activity_log (
  id uuid primary key default gen_random_uuid(),
  club_id uuid not null references public.clubs(id) on delete restrict,
  inquiry_id uuid not null references public.player_inquiries(id) on delete cascade,
  actor_profile_id uuid references public.profiles(id) on delete set null,
  activity_type text not null,
  from_stage text references public.pipeline_stages(id),
  to_stage text references public.pipeline_stages(id),
  body text,
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  deleted_at timestamptz
);

create table public.document_types (
  id uuid primary key default gen_random_uuid(),
  club_id uuid references public.clubs(id) on delete cascade,
  name text not null,
  description text,
  applies_to public.document_owner_type[] not null default '{}',
  is_default boolean not null default false,
  sort_order integer not null default 100,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  deleted_at timestamptz
);

create table public.documents (
  id uuid primary key default gen_random_uuid(),
  club_id uuid not null references public.clubs(id) on delete restrict,
  owner_type public.document_owner_type not null,
  owner_id uuid not null,
  document_type_id uuid not null references public.document_types(id) on delete restrict,
  status text not null default 'missing' references public.document_statuses(id),
  file_path text,
  file_name text,
  mime_type text,
  uploaded_by_profile_id uuid references public.profiles(id) on delete set null,
  reviewed_by_profile_id uuid references public.profiles(id) on delete set null,
  reviewed_at timestamptz,
  expires_at timestamptz,
  notes text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  deleted_at timestamptz
);

create table public.document_requirements (
  id uuid primary key default gen_random_uuid(),
  club_id uuid not null references public.clubs(id) on delete restrict,
  document_type_id uuid not null references public.document_types(id) on delete restrict,
  owner_type public.document_owner_type not null,
  age_group text references public.age_groups(id),
  team_level text references public.team_levels(id),
  team_id uuid references public.teams(id) on delete cascade,
  is_required boolean not null default true,
  due_at timestamptz,
  notes text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  deleted_at timestamptz
);

create table public.leagues (
  id uuid primary key default gen_random_uuid(),
  club_id uuid not null references public.clubs(id) on delete restrict,
  name text not null,
  governing_body text,
  season_id uuid references public.seasons(id) on delete set null,
  notes text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  deleted_at timestamptz,
  constraint leagues_club_name_season_unique unique (club_id, name, season_id)
);

create table public.team_leagues (
  id uuid primary key default gen_random_uuid(),
  club_id uuid not null references public.clubs(id) on delete restrict,
  team_id uuid not null references public.teams(id) on delete cascade,
  league_id uuid not null references public.leagues(id) on delete cascade,
  league_role public.league_role not null default 'primary',
  registration_status text,
  roster_upload_deadline timestamptz,
  schedule_release_date date,
  notes text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  deleted_at timestamptz
);

create table public.tournaments (
  id uuid primary key default gen_random_uuid(),
  club_id uuid not null references public.clubs(id) on delete restrict,
  name text not null,
  start_date date not null,
  end_date date not null,
  location text,
  governing_body text,
  notes text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  deleted_at timestamptz,
  constraint tournaments_dates_valid check (start_date <= end_date),
  constraint tournaments_club_name_dates_unique unique (club_id, name, start_date)
);

create table public.team_tournaments (
  id uuid primary key default gen_random_uuid(),
  club_id uuid not null references public.clubs(id) on delete restrict,
  team_id uuid not null references public.teams(id) on delete cascade,
  tournament_id uuid not null references public.tournaments(id) on delete cascade,
  status public.tournament_status not null default 'projected',
  cost numeric(10, 2),
  notes text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  deleted_at timestamptz,
  constraint team_tournaments_cost_positive check (cost is null or cost >= 0),
  constraint team_tournaments_unique unique (team_id, tournament_id)
);

create table public.tournament_deadlines (
  id uuid primary key default gen_random_uuid(),
  club_id uuid not null references public.clubs(id) on delete restrict,
  team_tournament_id uuid not null references public.team_tournaments(id) on delete cascade,
  deadline_type public.tournament_deadline_type not null,
  due_at timestamptz not null,
  status text not null default 'open' references public.task_statuses(id),
  notes text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  deleted_at timestamptz
);

create table public.matches (
  id uuid primary key default gen_random_uuid(),
  club_id uuid not null references public.clubs(id) on delete restrict,
  team_id uuid not null references public.teams(id) on delete cascade,
  league_id uuid references public.leagues(id) on delete set null,
  tournament_id uuid references public.tournaments(id) on delete set null,
  opponent text not null,
  match_date date not null,
  kickoff_time time,
  arrival_time time,
  location text,
  field_number text,
  jersey_color text,
  shorts_color text,
  socks_color text,
  status public.match_status not null default 'scheduled',
  coach_notes text,
  parent_notes text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  deleted_at timestamptz
);

create table public.match_rosters (
  id uuid primary key default gen_random_uuid(),
  club_id uuid not null references public.clubs(id) on delete restrict,
  match_id uuid not null references public.matches(id) on delete cascade,
  player_id uuid not null references public.players(id) on delete cascade,
  roster_role public.match_roster_role not null default 'regular',
  availability_status text not null default 'unknown',
  notes text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  deleted_at timestamptz,
  constraint match_rosters_availability_valid check (
    availability_status in ('unknown', 'available', 'unavailable', 'maybe')
  ),
  constraint match_rosters_match_player_unique unique (match_id, player_id)
);

create table public.player_status_history (
  id uuid primary key default gen_random_uuid(),
  club_id uuid not null references public.clubs(id) on delete restrict,
  player_id uuid not null references public.players(id) on delete cascade,
  from_status public.player_status,
  to_status public.player_status not null,
  changed_by_profile_id uuid references public.profiles(id) on delete set null,
  reason text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  deleted_at timestamptz
);

create table public.roster_movement_log (
  id uuid primary key default gen_random_uuid(),
  club_id uuid not null references public.clubs(id) on delete restrict,
  player_id uuid not null references public.players(id) on delete cascade,
  from_team_id uuid references public.teams(id) on delete set null,
  to_team_id uuid references public.teams(id) on delete set null,
  from_assignment_type public.roster_assignment_type,
  to_assignment_type public.roster_assignment_type,
  moved_by_profile_id uuid references public.profiles(id) on delete set null,
  reason text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  deleted_at timestamptz
);

create table public.staff_activity_log (
  id uuid primary key default gen_random_uuid(),
  club_id uuid not null references public.clubs(id) on delete restrict,
  actor_profile_id uuid references public.profiles(id) on delete set null,
  target_profile_id uuid references public.profiles(id) on delete set null,
  team_id uuid references public.teams(id) on delete set null,
  activity_type text not null,
  body text,
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  deleted_at timestamptz
);

create unique index document_types_default_name_unique
  on public.document_types (lower(name))
  where club_id is null and deleted_at is null;

create unique index document_types_club_name_unique
  on public.document_types (club_id, lower(name))
  where club_id is not null and deleted_at is null;

create unique index roster_assignments_one_active_home_team
  on public.roster_assignments (player_id, season_id)
  where is_home_team and deleted_at is null and end_date is null;

create unique index team_leagues_one_primary_league
  on public.team_leagues (team_id)
  where league_role = 'primary' and deleted_at is null;

create index idx_seasons_club_id on public.seasons (club_id) where deleted_at is null;
create index idx_profiles_club_id on public.profiles (club_id) where deleted_at is null;
create index idx_profiles_user_id on public.profiles (user_id) where deleted_at is null;
create index idx_profiles_role on public.profiles (club_id, role) where deleted_at is null;
create index idx_teams_club_id on public.teams (club_id) where deleted_at is null;
create index idx_teams_season_id on public.teams (season_id) where deleted_at is null;
create index idx_teams_age_gender_format on public.teams (club_id, age_group, gender, team_format) where deleted_at is null;
create index idx_team_staff_team_id on public.team_staff (team_id) where deleted_at is null;
create index idx_team_staff_profile_id on public.team_staff (profile_id) where deleted_at is null;
create index idx_players_club_id on public.players (club_id) where deleted_at is null;
create index idx_players_home_team_id on public.players (home_team_id) where deleted_at is null;
create index idx_players_status on public.players (club_id, status) where deleted_at is null;
create index idx_players_name on public.players (club_id, last_name, first_name) where deleted_at is null;
create index idx_players_parent_profile_id on public.players (parent_profile_id) where deleted_at is null;
create index idx_roster_assignments_player_id on public.roster_assignments (player_id) where deleted_at is null;
create index idx_roster_assignments_team_id on public.roster_assignments (team_id) where deleted_at is null;
create index idx_roster_assignments_club_season on public.roster_assignments (club_id, season_id) where deleted_at is null;
create index idx_player_inquiries_club_id on public.player_inquiries (club_id) where deleted_at is null;
create index idx_player_inquiries_stage on public.player_inquiries (club_id, pipeline_stage) where deleted_at is null;
create index idx_player_inquiries_interested_team on public.player_inquiries (interested_team_id) where deleted_at is null;
create index idx_player_inquiries_assigned_coach on public.player_inquiries (assigned_coach_id) where deleted_at is null;
create index idx_player_inquiries_assigned_manager on public.player_inquiries (assigned_manager_id) where deleted_at is null;
create index idx_player_inquiries_assigned_admin on public.player_inquiries (assigned_admin_id) where deleted_at is null;
create index idx_player_inquiries_next_action_due on public.player_inquiries (next_action_due_at) where deleted_at is null;
create index idx_pipeline_tasks_inquiry_id on public.pipeline_tasks (inquiry_id) where deleted_at is null;
create index idx_pipeline_tasks_assigned_to on public.pipeline_tasks (assigned_to_profile_id) where deleted_at is null;
create index idx_pipeline_tasks_status_due on public.pipeline_tasks (club_id, status, due_at) where deleted_at is null;
create index idx_trial_events_inquiry_id on public.trial_events (inquiry_id) where deleted_at is null;
create index idx_trial_events_team_id on public.trial_events (team_id) where deleted_at is null;
create index idx_trial_events_coach on public.trial_events (assigned_coach_id) where deleted_at is null;
create index idx_trial_evaluations_inquiry_id on public.trial_evaluations (inquiry_id) where deleted_at is null;
create index idx_pipeline_activity_inquiry_id on public.pipeline_activity_log (inquiry_id) where deleted_at is null;
create index idx_documents_club_id on public.documents (club_id) where deleted_at is null;
create index idx_documents_owner on public.documents (owner_type, owner_id) where deleted_at is null;
create index idx_documents_type_id on public.documents (document_type_id) where deleted_at is null;
create index idx_documents_status on public.documents (club_id, status) where deleted_at is null;
create index idx_documents_expires_at on public.documents (expires_at) where deleted_at is null;
create index idx_document_requirements_club_id on public.document_requirements (club_id) where deleted_at is null;
create index idx_document_requirements_owner on public.document_requirements (owner_type, team_id, age_group, team_level) where deleted_at is null;
create index idx_leagues_club_id on public.leagues (club_id) where deleted_at is null;
create index idx_team_leagues_team_id on public.team_leagues (team_id) where deleted_at is null;
create index idx_team_leagues_league_id on public.team_leagues (league_id) where deleted_at is null;
create index idx_matches_team_date on public.matches (team_id, match_date) where deleted_at is null;
create index idx_matches_status on public.matches (club_id, status, match_date) where deleted_at is null;
create index idx_matches_league_id on public.matches (league_id) where deleted_at is null;
create index idx_matches_tournament_id on public.matches (tournament_id) where deleted_at is null;
create index idx_match_rosters_match_id on public.match_rosters (match_id) where deleted_at is null;
create index idx_match_rosters_player_id on public.match_rosters (player_id) where deleted_at is null;
create index idx_tournaments_club_dates on public.tournaments (club_id, start_date, end_date) where deleted_at is null;
create index idx_team_tournaments_team_id on public.team_tournaments (team_id) where deleted_at is null;
create index idx_team_tournaments_tournament_id on public.team_tournaments (tournament_id) where deleted_at is null;
create index idx_team_tournaments_status on public.team_tournaments (club_id, status) where deleted_at is null;
create index idx_tournament_deadlines_team_tournament on public.tournament_deadlines (team_tournament_id) where deleted_at is null;
create index idx_tournament_deadlines_due_status on public.tournament_deadlines (club_id, status, due_at) where deleted_at is null;
create index idx_player_status_history_player_id on public.player_status_history (player_id, created_at desc) where deleted_at is null;
create index idx_roster_movement_player_id on public.roster_movement_log (player_id, created_at desc) where deleted_at is null;
create index idx_staff_activity_actor on public.staff_activity_log (actor_profile_id, created_at desc) where deleted_at is null;
create index idx_staff_activity_team on public.staff_activity_log (team_id, created_at desc) where deleted_at is null;

create or replace function private.current_user_profile_id()
returns uuid
language sql
stable
security definer
set search_path = public, auth, pg_temp
as $$
  select p.id
  from public.profiles p
  where p.user_id = auth.uid()
    and p.deleted_at is null
    and p.is_active
  limit 1
$$;

create or replace function private.current_user_club_id()
returns uuid
language sql
stable
security definer
set search_path = public, auth, pg_temp
as $$
  select p.club_id
  from public.profiles p
  where p.user_id = auth.uid()
    and p.deleted_at is null
    and p.is_active
  limit 1
$$;

create or replace function private.current_user_role()
returns public.user_role
language sql
stable
security definer
set search_path = public, auth, pg_temp
as $$
  select p.role
  from public.profiles p
  where p.user_id = auth.uid()
    and p.deleted_at is null
    and p.is_active
  limit 1
$$;

create or replace function private.is_doc_or_club_manager()
returns boolean
language sql
stable
security definer
set search_path = public, auth, pg_temp
as $$
  select coalesce(private.current_user_role() in ('doc', 'club_manager'), false)
$$;

create or replace function private.is_team_staff(p_team_id uuid)
returns boolean
language sql
stable
security definer
set search_path = public, auth, pg_temp
as $$
  select exists (
    select 1
    from public.team_staff ts
    join public.profiles p on p.id = ts.profile_id
    where ts.team_id = p_team_id
      and p.user_id = auth.uid()
      and p.deleted_at is null
      and p.is_active
      and ts.deleted_at is null
      and (ts.end_date is null or ts.end_date >= current_date)
  )
$$;

create or replace function private.can_access_player(p_player_id uuid)
returns boolean
language sql
stable
security definer
set search_path = public, auth, pg_temp
as $$
  select exists (
    select 1
    from public.players pl
    where pl.id = p_player_id
      and pl.deleted_at is null
      and pl.club_id = private.current_user_club_id()
      and (
        private.is_doc_or_club_manager()
        or pl.parent_profile_id = private.current_user_profile_id()
        or pl.player_profile_id = private.current_user_profile_id()
        or private.is_team_staff(pl.home_team_id)
        or exists (
          select 1
          from public.roster_assignments ra
          where ra.player_id = pl.id
            and ra.deleted_at is null
            and (ra.end_date is null or ra.end_date >= current_date)
            and private.is_team_staff(ra.team_id)
        )
      )
  )
$$;

create or replace function private.can_access_inquiry(p_inquiry_id uuid)
returns boolean
language sql
stable
security definer
set search_path = public, auth, pg_temp
as $$
  select exists (
    select 1
    from public.player_inquiries i
    where i.id = p_inquiry_id
      and i.deleted_at is null
      and i.club_id = private.current_user_club_id()
      and (
        private.is_doc_or_club_manager()
        or private.current_user_profile_id() in (i.assigned_coach_id, i.assigned_manager_id, i.assigned_admin_id)
        or private.is_team_staff(i.interested_team_id)
      )
  )
$$;

create or replace function private.can_access_match(p_match_id uuid)
returns boolean
language sql
stable
security definer
set search_path = public, auth, pg_temp
as $$
  select exists (
    select 1
    from public.matches m
    where m.id = p_match_id
      and m.deleted_at is null
      and m.club_id = private.current_user_club_id()
      and (
        private.is_doc_or_club_manager()
        or private.is_team_staff(m.team_id)
      )
  )
$$;

create or replace function private.can_access_team_tournament(p_team_tournament_id uuid)
returns boolean
language sql
stable
security definer
set search_path = public, auth, pg_temp
as $$
  select exists (
    select 1
    from public.team_tournaments tt
    where tt.id = p_team_tournament_id
      and tt.deleted_at is null
      and tt.club_id = private.current_user_club_id()
      and (
        private.is_doc_or_club_manager()
        or private.is_team_staff(tt.team_id)
      )
  )
$$;

create or replace function private.can_access_document(
  p_owner_type public.document_owner_type,
  p_owner_id uuid
)
returns boolean
language plpgsql
stable
security definer
set search_path = public, auth, pg_temp
as $$
begin
  if private.is_doc_or_club_manager() then
    return true;
  end if;

  case p_owner_type
    when 'player' then
      return private.can_access_player(p_owner_id);
    when 'inquiry' then
      return private.can_access_inquiry(p_owner_id);
    when 'team' then
      return private.is_team_staff(p_owner_id);
    when 'match' then
      return private.can_access_match(p_owner_id);
    when 'tournament' then
      return exists (
        select 1
        from public.team_tournaments tt
        where tt.tournament_id = p_owner_id
          and tt.deleted_at is null
          and private.is_team_staff(tt.team_id)
      );
    when 'staff' then
      return p_owner_id = private.current_user_profile_id()
        or exists (
          select 1
          from public.team_staff mine
          join public.team_staff theirs on theirs.team_id = mine.team_id
          where mine.profile_id = private.current_user_profile_id()
            and theirs.profile_id = p_owner_id
            and mine.deleted_at is null
            and theirs.deleted_at is null
        );
    else
      return false;
  end case;
end;
$$;

create or replace function private.set_updated_at()
returns trigger
language plpgsql
set search_path = public, pg_temp
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

create or replace function private.enforce_player_update_rules()
returns trigger
language plpgsql
security definer
set search_path = public, auth, pg_temp
as $$
begin
  if current_user in ('postgres', 'service_role', 'supabase_admin') then
    return new;
  end if;

  if old.home_team_id is distinct from new.home_team_id
    and not private.is_doc_or_club_manager() then
    raise exception 'Only DOC or Club Manager can change a player home team'
      using errcode = '42501';
  end if;

  if old.status is distinct from new.status
    and new.status = 'rostered'
    and not private.is_doc_or_club_manager() then
    raise exception 'Only DOC or Club Manager can roster a player'
      using errcode = '42501';
  end if;

  return new;
end;
$$;

create or replace function private.enforce_roster_assignment_rules()
returns trigger
language plpgsql
security definer
set search_path = public, auth, pg_temp
as $$
begin
  if new.assignment_type = 'home_team' then
    new.is_home_team = true;
  else
    new.is_home_team = false;
  end if;

  if current_user in ('postgres', 'service_role', 'supabase_admin') then
    return new;
  end if;

  if (tg_op = 'INSERT' and new.is_home_team)
    or (tg_op = 'UPDATE' and old.is_home_team is distinct from new.is_home_team)
    or (tg_op = 'UPDATE' and old.team_id is distinct from new.team_id and new.is_home_team) then
    if not private.is_doc_or_club_manager() then
      raise exception 'Only DOC or Club Manager can change official home-team roster assignments'
        using errcode = '42501';
    end if;
  end if;

  return new;
end;
$$;

create or replace function private.log_player_status_change()
returns trigger
language plpgsql
security definer
set search_path = public, auth, pg_temp
as $$
begin
  if tg_op = 'INSERT' then
    insert into public.player_status_history (
      club_id,
      player_id,
      from_status,
      to_status,
      changed_by_profile_id,
      reason
    )
    values (
      new.club_id,
      new.id,
      null,
      new.status,
      private.current_user_profile_id(),
      'initial_status'
    );
  elsif old.status is distinct from new.status then
    insert into public.player_status_history (
      club_id,
      player_id,
      from_status,
      to_status,
      changed_by_profile_id,
      reason
    )
    values (
      new.club_id,
      new.id,
      old.status,
      new.status,
      private.current_user_profile_id(),
      'status_changed'
    );
  end if;

  return new;
end;
$$;

create or replace function private.log_roster_assignment_change()
returns trigger
language plpgsql
security definer
set search_path = public, auth, pg_temp
as $$
begin
  if tg_op = 'INSERT' then
    insert into public.roster_movement_log (
      club_id,
      player_id,
      from_team_id,
      to_team_id,
      from_assignment_type,
      to_assignment_type,
      moved_by_profile_id,
      reason
    )
    values (
      new.club_id,
      new.player_id,
      null,
      new.team_id,
      null,
      new.assignment_type,
      private.current_user_profile_id(),
      'assignment_created'
    );
  elsif old.team_id is distinct from new.team_id
    or old.assignment_type is distinct from new.assignment_type
    or old.end_date is distinct from new.end_date then
    insert into public.roster_movement_log (
      club_id,
      player_id,
      from_team_id,
      to_team_id,
      from_assignment_type,
      to_assignment_type,
      moved_by_profile_id,
      reason
    )
    values (
      new.club_id,
      new.player_id,
      old.team_id,
      new.team_id,
      old.assignment_type,
      new.assignment_type,
      private.current_user_profile_id(),
      'assignment_changed'
    );
  end if;

  return new;
end;
$$;

create or replace function public.convert_inquiry_to_player(
  p_inquiry_id uuid,
  p_home_team_id uuid default null,
  p_jersey_number integer default null
)
returns uuid
language plpgsql
security invoker
set search_path = public, private, auth, pg_temp
as $$
declare
  v_inquiry public.player_inquiries;
  v_player_id uuid;
  v_season_id uuid;
begin
  if not private.is_doc_or_club_manager() then
    raise exception 'Only DOC or Club Manager can convert inquiries to rostered players'
      using errcode = '42501';
  end if;

  select *
  into v_inquiry
  from public.player_inquiries
  where id = p_inquiry_id
    and deleted_at is null;

  if not found then
    raise exception 'Inquiry not found'
      using errcode = 'P0002';
  end if;

  if v_inquiry.club_id <> private.current_user_club_id() then
    raise exception 'Inquiry is outside the current club'
      using errcode = '42501';
  end if;

  if p_home_team_id is not null then
    select t.season_id
    into v_season_id
    from public.teams t
    where t.id = p_home_team_id
      and t.club_id = v_inquiry.club_id
      and t.deleted_at is null;

    if not found then
      raise exception 'Home team not found for current club'
        using errcode = 'P0002';
    end if;
  end if;

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
    home_team_id,
    status,
    parent_name,
    parent_phone,
    parent_email,
    notes
  )
  values (
    v_inquiry.club_id,
    v_inquiry.player_first_name,
    v_inquiry.player_last_name,
    v_inquiry.preferred_name,
    v_inquiry.date_of_birth,
    v_inquiry.interested_age_group,
    v_inquiry.interested_age_group,
    v_inquiry.gender,
    v_inquiry.positions,
    p_jersey_number,
    p_home_team_id,
    case when p_home_team_id is null then 'registered'::public.player_status else 'rostered'::public.player_status end,
    v_inquiry.parent_guardian_name,
    v_inquiry.parent_guardian_phone,
    v_inquiry.parent_guardian_email,
    v_inquiry.notes
  )
  returning id into v_player_id;

  if p_home_team_id is not null then
    insert into public.roster_assignments (
      club_id,
      season_id,
      player_id,
      team_id,
      assignment_type,
      is_home_team,
      start_date
    )
    values (
      v_inquiry.club_id,
      v_season_id,
      v_player_id,
      p_home_team_id,
      'home_team',
      true,
      current_date
    );
  end if;

  update public.player_inquiries
  set pipeline_stage = 'rostered',
      converted_player_id = v_player_id,
      converted_at = now(),
      updated_at = now()
  where id = p_inquiry_id;

  insert into public.pipeline_activity_log (
    club_id,
    inquiry_id,
    actor_profile_id,
    activity_type,
    from_stage,
    to_stage,
    body
  )
  values (
    v_inquiry.club_id,
    p_inquiry_id,
    private.current_user_profile_id(),
    'converted_to_player',
    v_inquiry.pipeline_stage,
    'rostered',
    'Inquiry converted to official player record'
  );

  return v_player_id;
end;
$$;

do $$
declare
  table_name text;
begin
  foreach table_name in array array[
    'team_formats',
    'team_genders',
    'team_levels',
    'age_groups',
    'pipeline_stages',
    'task_statuses',
    'document_statuses',
    'clubs',
    'seasons',
    'profiles',
    'teams',
    'team_staff',
    'players',
    'roster_assignments',
    'player_inquiries',
    'pipeline_tasks',
    'trial_events',
    'trial_evaluations',
    'pipeline_activity_log',
    'document_types',
    'documents',
    'document_requirements',
    'leagues',
    'team_leagues',
    'matches',
    'match_rosters',
    'tournaments',
    'team_tournaments',
    'tournament_deadlines',
    'player_status_history',
    'roster_movement_log',
    'staff_activity_log'
  ]
  loop
    execute format('alter table public.%I enable row level security', table_name);
  end loop;
end $$;

do $$
declare
  table_name text;
begin
  foreach table_name in array array[
    'team_formats',
    'team_genders',
    'team_levels',
    'age_groups',
    'pipeline_stages',
    'task_statuses',
    'document_statuses'
  ]
  loop
    execute format(
      'create policy %I on public.%I for select to authenticated using (true)',
      table_name || '_authenticated_read',
      table_name
    );
  end loop;
end $$;

do $$
declare
  table_name text;
begin
  foreach table_name in array array[
    'seasons',
    'profiles',
    'teams',
    'team_staff',
    'players',
    'roster_assignments',
    'player_inquiries',
    'pipeline_tasks',
    'trial_events',
    'trial_evaluations',
    'pipeline_activity_log',
    'documents',
    'document_requirements',
    'leagues',
    'team_leagues',
    'matches',
    'match_rosters',
    'tournaments',
    'team_tournaments',
    'tournament_deadlines',
    'player_status_history',
    'roster_movement_log',
    'staff_activity_log'
  ]
  loop
    execute format(
      'create policy %I on public.%I for select to authenticated using (club_id = (select private.current_user_club_id()) and (select private.is_doc_or_club_manager()))',
      table_name || '_doc_manager_select',
      table_name
    );
    execute format(
      'create policy %I on public.%I for insert to authenticated with check (club_id = (select private.current_user_club_id()) and (select private.is_doc_or_club_manager()))',
      table_name || '_doc_manager_insert',
      table_name
    );
    execute format(
      'create policy %I on public.%I for update to authenticated using (club_id = (select private.current_user_club_id()) and (select private.is_doc_or_club_manager())) with check (club_id = (select private.current_user_club_id()) and (select private.is_doc_or_club_manager()))',
      table_name || '_doc_manager_update',
      table_name
    );
  end loop;
end $$;

create policy clubs_members_select
  on public.clubs for select
  to authenticated
  using (id = (select private.current_user_club_id()) and deleted_at is null);

create policy clubs_doc_manager_update
  on public.clubs for update
  to authenticated
  using (id = (select private.current_user_club_id()) and (select private.is_doc_or_club_manager()))
  with check (id = (select private.current_user_club_id()) and (select private.is_doc_or_club_manager()));

create policy document_types_member_select
  on public.document_types for select
  to authenticated
  using (
    deleted_at is null
    and (
      club_id is null
      or club_id = (select private.current_user_club_id())
    )
  );

create policy document_types_doc_manager_insert
  on public.document_types for insert
  to authenticated
  with check (
    club_id = (select private.current_user_club_id())
    and (select private.is_doc_or_club_manager())
  );

create policy document_types_doc_manager_update
  on public.document_types for update
  to authenticated
  using (
    club_id = (select private.current_user_club_id())
    and (select private.is_doc_or_club_manager())
  )
  with check (
    club_id = (select private.current_user_club_id())
    and (select private.is_doc_or_club_manager())
  );

create policy seasons_member_select
  on public.seasons for select
  to authenticated
  using (club_id = (select private.current_user_club_id()) and deleted_at is null);

create policy teams_member_select
  on public.teams for select
  to authenticated
  using (club_id = (select private.current_user_club_id()) and deleted_at is null);

create policy teams_staff_update
  on public.teams for update
  to authenticated
  using (
    club_id = (select private.current_user_club_id())
    and deleted_at is null
    and (select private.is_team_staff(id))
  )
  with check (
    club_id = (select private.current_user_club_id())
    and (select private.is_team_staff(id))
  );

create policy profiles_self_select
  on public.profiles for select
  to authenticated
  using (id = (select private.current_user_profile_id()) and deleted_at is null);

create policy profiles_team_staff_select
  on public.profiles for select
  to authenticated
  using (
    club_id = (select private.current_user_club_id())
    and deleted_at is null
    and exists (
      select 1
      from public.team_staff mine
      join public.team_staff theirs on theirs.team_id = mine.team_id
      where mine.profile_id = (select private.current_user_profile_id())
        and theirs.profile_id = profiles.id
        and mine.deleted_at is null
        and theirs.deleted_at is null
    )
  );

create policy team_staff_self_or_team_select
  on public.team_staff for select
  to authenticated
  using (
    club_id = (select private.current_user_club_id())
    and deleted_at is null
    and (
      profile_id = (select private.current_user_profile_id())
      or (select private.is_team_staff(team_id))
    )
  );

create policy players_access_select
  on public.players for select
  to authenticated
  using (
    club_id = (select private.current_user_club_id())
    and deleted_at is null
    and (select private.can_access_player(id))
  );

create policy players_access_update
  on public.players for update
  to authenticated
  using (
    club_id = (select private.current_user_club_id())
    and deleted_at is null
    and (select private.can_access_player(id))
  )
  with check (
    club_id = (select private.current_user_club_id())
    and (select private.can_access_player(id))
  );

create policy roster_assignments_access_select
  on public.roster_assignments for select
  to authenticated
  using (
    club_id = (select private.current_user_club_id())
    and deleted_at is null
    and (
      (select private.can_access_player(player_id))
      or (select private.is_team_staff(team_id))
    )
  );

create policy player_inquiries_assigned_select
  on public.player_inquiries for select
  to authenticated
  using (
    club_id = (select private.current_user_club_id())
    and deleted_at is null
    and (select private.can_access_inquiry(id))
  );

create policy player_inquiries_staff_insert
  on public.player_inquiries for insert
  to authenticated
  with check (
    club_id = (select private.current_user_club_id())
    and (select private.current_user_role()) in ('doc', 'club_manager', 'head_coach', 'assistant_coach', 'team_manager')
  );

create policy player_inquiries_assigned_update
  on public.player_inquiries for update
  to authenticated
  using (
    club_id = (select private.current_user_club_id())
    and deleted_at is null
    and (select private.can_access_inquiry(id))
  )
  with check (
    club_id = (select private.current_user_club_id())
    and (select private.can_access_inquiry(id))
  );

create policy pipeline_tasks_assigned_select
  on public.pipeline_tasks for select
  to authenticated
  using (
    club_id = (select private.current_user_club_id())
    and deleted_at is null
    and (
      assigned_to_profile_id = (select private.current_user_profile_id())
      or (select private.can_access_inquiry(inquiry_id))
    )
  );

create policy pipeline_tasks_staff_insert
  on public.pipeline_tasks for insert
  to authenticated
  with check (
    club_id = (select private.current_user_club_id())
    and (
      assigned_to_profile_id = (select private.current_user_profile_id())
      or (select private.can_access_inquiry(inquiry_id))
    )
  );

create policy pipeline_tasks_staff_update
  on public.pipeline_tasks for update
  to authenticated
  using (
    club_id = (select private.current_user_club_id())
    and deleted_at is null
    and (
      assigned_to_profile_id = (select private.current_user_profile_id())
      or (select private.can_access_inquiry(inquiry_id))
    )
  )
  with check (
    club_id = (select private.current_user_club_id())
    and (
      assigned_to_profile_id = (select private.current_user_profile_id())
      or (select private.can_access_inquiry(inquiry_id))
    )
  );

create policy trial_events_staff_select
  on public.trial_events for select
  to authenticated
  using (
    club_id = (select private.current_user_club_id())
    and deleted_at is null
    and (
      assigned_coach_id = (select private.current_user_profile_id())
      or (select private.can_access_inquiry(inquiry_id))
      or (select private.is_team_staff(team_id))
    )
  );

create policy trial_events_staff_insert
  on public.trial_events for insert
  to authenticated
  with check (
    club_id = (select private.current_user_club_id())
    and (
      assigned_coach_id = (select private.current_user_profile_id())
      or (select private.can_access_inquiry(inquiry_id))
      or (select private.is_team_staff(team_id))
    )
  );

create policy trial_events_staff_update
  on public.trial_events for update
  to authenticated
  using (
    club_id = (select private.current_user_club_id())
    and deleted_at is null
    and (
      assigned_coach_id = (select private.current_user_profile_id())
      or (select private.can_access_inquiry(inquiry_id))
      or (select private.is_team_staff(team_id))
    )
  )
  with check (
    club_id = (select private.current_user_club_id())
    and (
      assigned_coach_id = (select private.current_user_profile_id())
      or (select private.can_access_inquiry(inquiry_id))
      or (select private.is_team_staff(team_id))
    )
  );

create policy trial_evaluations_staff_select
  on public.trial_evaluations for select
  to authenticated
  using (
    club_id = (select private.current_user_club_id())
    and deleted_at is null
    and (
      evaluator_profile_id = (select private.current_user_profile_id())
      or (select private.can_access_inquiry(inquiry_id))
    )
  );

create policy trial_evaluations_staff_insert
  on public.trial_evaluations for insert
  to authenticated
  with check (
    club_id = (select private.current_user_club_id())
    and (
      evaluator_profile_id = (select private.current_user_profile_id())
      or (select private.can_access_inquiry(inquiry_id))
    )
  );

create policy trial_evaluations_staff_update
  on public.trial_evaluations for update
  to authenticated
  using (
    club_id = (select private.current_user_club_id())
    and deleted_at is null
    and (
      evaluator_profile_id = (select private.current_user_profile_id())
      or (select private.can_access_inquiry(inquiry_id))
    )
  )
  with check (
    club_id = (select private.current_user_club_id())
    and (
      evaluator_profile_id = (select private.current_user_profile_id())
      or (select private.can_access_inquiry(inquiry_id))
    )
  );

create policy pipeline_activity_staff_select
  on public.pipeline_activity_log for select
  to authenticated
  using (
    club_id = (select private.current_user_club_id())
    and deleted_at is null
    and (select private.can_access_inquiry(inquiry_id))
  );

create policy pipeline_activity_staff_insert
  on public.pipeline_activity_log for insert
  to authenticated
  with check (
    club_id = (select private.current_user_club_id())
    and (
      actor_profile_id = (select private.current_user_profile_id())
      or actor_profile_id is null
    )
    and (select private.can_access_inquiry(inquiry_id))
  );

create policy documents_owner_select
  on public.documents for select
  to authenticated
  using (
    club_id = (select private.current_user_club_id())
    and deleted_at is null
    and (select private.can_access_document(owner_type, owner_id))
  );

create policy documents_owner_insert
  on public.documents for insert
  to authenticated
  with check (
    club_id = (select private.current_user_club_id())
    and (select private.can_access_document(owner_type, owner_id))
  );

create policy documents_owner_update
  on public.documents for update
  to authenticated
  using (
    club_id = (select private.current_user_club_id())
    and deleted_at is null
    and (select private.can_access_document(owner_type, owner_id))
  )
  with check (
    club_id = (select private.current_user_club_id())
    and (select private.can_access_document(owner_type, owner_id))
  );

create policy document_requirements_member_select
  on public.document_requirements for select
  to authenticated
  using (club_id = (select private.current_user_club_id()) and deleted_at is null);

create policy leagues_member_select
  on public.leagues for select
  to authenticated
  using (club_id = (select private.current_user_club_id()) and deleted_at is null);

create policy team_leagues_staff_select
  on public.team_leagues for select
  to authenticated
  using (
    club_id = (select private.current_user_club_id())
    and deleted_at is null
    and (select private.is_team_staff(team_id))
  );

create policy team_leagues_staff_update
  on public.team_leagues for update
  to authenticated
  using (
    club_id = (select private.current_user_club_id())
    and deleted_at is null
    and (select private.is_team_staff(team_id))
  )
  with check (
    club_id = (select private.current_user_club_id())
    and (select private.is_team_staff(team_id))
  );

create policy tournaments_member_select
  on public.tournaments for select
  to authenticated
  using (club_id = (select private.current_user_club_id()) and deleted_at is null);

create policy team_tournaments_staff_select
  on public.team_tournaments for select
  to authenticated
  using (
    club_id = (select private.current_user_club_id())
    and deleted_at is null
    and (select private.is_team_staff(team_id))
  );

create policy team_tournaments_staff_update
  on public.team_tournaments for update
  to authenticated
  using (
    club_id = (select private.current_user_club_id())
    and deleted_at is null
    and (select private.is_team_staff(team_id))
  )
  with check (
    club_id = (select private.current_user_club_id())
    and (select private.is_team_staff(team_id))
  );

create policy tournament_deadlines_staff_select
  on public.tournament_deadlines for select
  to authenticated
  using (
    club_id = (select private.current_user_club_id())
    and deleted_at is null
    and (select private.can_access_team_tournament(team_tournament_id))
  );

create policy tournament_deadlines_staff_insert
  on public.tournament_deadlines for insert
  to authenticated
  with check (
    club_id = (select private.current_user_club_id())
    and (select private.can_access_team_tournament(team_tournament_id))
  );

create policy tournament_deadlines_staff_update
  on public.tournament_deadlines for update
  to authenticated
  using (
    club_id = (select private.current_user_club_id())
    and deleted_at is null
    and (select private.can_access_team_tournament(team_tournament_id))
  )
  with check (
    club_id = (select private.current_user_club_id())
    and (select private.can_access_team_tournament(team_tournament_id))
  );

create policy matches_staff_select
  on public.matches for select
  to authenticated
  using (
    club_id = (select private.current_user_club_id())
    and deleted_at is null
    and (select private.is_team_staff(team_id))
  );

create policy matches_staff_insert
  on public.matches for insert
  to authenticated
  with check (
    club_id = (select private.current_user_club_id())
    and (select private.is_team_staff(team_id))
  );

create policy matches_staff_update
  on public.matches for update
  to authenticated
  using (
    club_id = (select private.current_user_club_id())
    and deleted_at is null
    and (select private.is_team_staff(team_id))
  )
  with check (
    club_id = (select private.current_user_club_id())
    and (select private.is_team_staff(team_id))
  );

create policy match_rosters_staff_select
  on public.match_rosters for select
  to authenticated
  using (
    club_id = (select private.current_user_club_id())
    and deleted_at is null
    and (
      (select private.can_access_match(match_id))
      or (select private.can_access_player(player_id))
    )
  );

create policy match_rosters_staff_insert
  on public.match_rosters for insert
  to authenticated
  with check (
    club_id = (select private.current_user_club_id())
    and (select private.can_access_match(match_id))
  );

create policy match_rosters_staff_update
  on public.match_rosters for update
  to authenticated
  using (
    club_id = (select private.current_user_club_id())
    and deleted_at is null
    and (select private.can_access_match(match_id))
  )
  with check (
    club_id = (select private.current_user_club_id())
    and (select private.can_access_match(match_id))
  );

create policy player_status_history_access_select
  on public.player_status_history for select
  to authenticated
  using (
    club_id = (select private.current_user_club_id())
    and deleted_at is null
    and (select private.can_access_player(player_id))
  );

create policy roster_movement_access_select
  on public.roster_movement_log for select
  to authenticated
  using (
    club_id = (select private.current_user_club_id())
    and deleted_at is null
    and (
      (select private.can_access_player(player_id))
      or (select private.is_team_staff(from_team_id))
      or (select private.is_team_staff(to_team_id))
    )
  );

create policy staff_activity_self_select
  on public.staff_activity_log for select
  to authenticated
  using (
    club_id = (select private.current_user_club_id())
    and deleted_at is null
    and (
      actor_profile_id = (select private.current_user_profile_id())
      or target_profile_id = (select private.current_user_profile_id())
      or (select private.is_team_staff(team_id))
    )
  );

create policy staff_activity_self_insert
  on public.staff_activity_log for insert
  to authenticated
  with check (
    club_id = (select private.current_user_club_id())
    and (
      actor_profile_id = (select private.current_user_profile_id())
      or actor_profile_id is null
    )
  );

do $$
declare
  table_name text;
begin
  foreach table_name in array array[
    'team_formats',
    'team_genders',
    'team_levels',
    'age_groups',
    'pipeline_stages',
    'task_statuses',
    'document_statuses',
    'clubs',
    'seasons',
    'profiles',
    'teams',
    'team_staff',
    'players',
    'roster_assignments',
    'player_inquiries',
    'pipeline_tasks',
    'trial_events',
    'trial_evaluations',
    'pipeline_activity_log',
    'document_types',
    'documents',
    'document_requirements',
    'leagues',
    'team_leagues',
    'matches',
    'match_rosters',
    'tournaments',
    'team_tournaments',
    'tournament_deadlines',
    'player_status_history',
    'roster_movement_log',
    'staff_activity_log'
  ]
  loop
    execute format(
      'create trigger %I before update on public.%I for each row execute function private.set_updated_at()',
      table_name || '_set_updated_at',
      table_name
    );
  end loop;
end $$;

create trigger players_enforce_update_rules
  before update on public.players
  for each row execute function private.enforce_player_update_rules();

create trigger roster_assignments_enforce_rules
  before insert or update on public.roster_assignments
  for each row execute function private.enforce_roster_assignment_rules();

create trigger players_log_initial_status
  after insert on public.players
  for each row execute function private.log_player_status_change();

create trigger players_log_status_change
  after update of status on public.players
  for each row execute function private.log_player_status_change();

create trigger roster_assignments_log_insert
  after insert on public.roster_assignments
  for each row execute function private.log_roster_assignment_change();

create trigger roster_assignments_log_update
  after update of team_id, assignment_type, end_date on public.roster_assignments
  for each row execute function private.log_roster_assignment_change();

revoke all on all tables in schema public from anon;
revoke execute on all functions in schema public from anon;
grant usage on schema public to authenticated, service_role;
grant select, insert, update, delete on all tables in schema public to authenticated, service_role;
grant usage, select on all sequences in schema public to authenticated, service_role;
grant execute on all functions in schema private to authenticated, service_role;
grant execute on function public.convert_inquiry_to_player(uuid, uuid, integer) to authenticated, service_role;

commit;
