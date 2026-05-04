begin;

insert into public.team_formats (id, label, sort_order)
values
  ('4v4', '4v4', 10),
  ('7v7', '7v7', 20),
  ('9v9', '9v9', 30),
  ('11v11', '11v11', 40)
on conflict (id) do update
set label = excluded.label,
    sort_order = excluded.sort_order,
    updated_at = now();

insert into public.team_genders (id, label, sort_order)
values
  ('boys', 'Boys', 10),
  ('girls', 'Girls', 20),
  ('coed', 'Coed', 30)
on conflict (id) do update
set label = excluded.label,
    sort_order = excluded.sort_order,
    updated_at = now();

insert into public.team_levels (id, label, sort_order)
values
  ('academy', 'Academy', 10),
  ('select', 'Select', 20),
  ('pre_ecnl', 'Pre-ECNL', 30),
  ('ecnl', 'ECNL', 40),
  ('rec', 'Rec', 50)
on conflict (id) do update
set label = excluded.label,
    sort_order = excluded.sort_order,
    updated_at = now();

insert into public.age_groups (id, label, sort_order, min_age, max_age, eligible_format_ids)
values
  ('U4', 'U4', 4, 4, 4, array['4v4']),
  ('U5', 'U5', 5, 5, 5, array['4v4']),
  ('U6', 'U6', 6, 6, 6, array['4v4']),
  ('U7', 'U7', 7, 7, 7, array['4v4']),
  ('U8', 'U8', 8, 8, 8, array['4v4', '7v7']),
  ('U9', 'U9', 9, 9, 9, array['7v7', '9v9']),
  ('U10', 'U10', 10, 10, 10, array['7v7', '9v9']),
  ('U11', 'U11', 11, 11, 11, array['9v9', '11v11']),
  ('U12', 'U12', 12, 12, 12, array['9v9', '11v11']),
  ('U13', 'U13', 13, 13, 13, array['11v11']),
  ('U14', 'U14', 14, 14, 14, array['11v11']),
  ('U15', 'U15', 15, 15, 15, array['11v11']),
  ('U16', 'U16', 16, 16, 16, array['11v11']),
  ('U17', 'U17', 17, 17, 17, array['11v11']),
  ('U18', 'U18', 18, 18, 18, array['11v11'])
on conflict (id) do update
set label = excluded.label,
    sort_order = excluded.sort_order,
    min_age = excluded.min_age,
    max_age = excluded.max_age,
    eligible_format_ids = excluded.eligible_format_ids,
    updated_at = now();

insert into public.pipeline_stages (id, label, sort_order, is_terminal)
values
  ('new', 'New', 10, false),
  ('assigned', 'Assigned', 20, false),
  ('contacted', 'Contacted', 30, false),
  ('trial_scheduled', 'Trial Scheduled', 40, false),
  ('trial_completed', 'Trial Completed', 50, false),
  ('offered', 'Offered', 60, false),
  ('registration_pending', 'Registration Pending', 70, false),
  ('documents_pending', 'Documents Pending', 80, false),
  ('ready_to_roster', 'Ready to Roster', 90, false),
  ('rostered', 'Rostered', 100, true),
  ('closed', 'Closed', 110, true)
on conflict (id) do update
set label = excluded.label,
    sort_order = excluded.sort_order,
    is_terminal = excluded.is_terminal,
    updated_at = now();

insert into public.task_statuses (id, label, sort_order, is_terminal)
values
  ('open', 'Open', 10, false),
  ('in_progress', 'In Progress', 20, false),
  ('blocked', 'Blocked', 30, false),
  ('completed', 'Completed', 40, true),
  ('canceled', 'Canceled', 50, true)
on conflict (id) do update
set label = excluded.label,
    sort_order = excluded.sort_order,
    is_terminal = excluded.is_terminal,
    updated_at = now();

insert into public.document_statuses (id, label, sort_order, is_terminal)
values
  ('missing', 'Missing', 10, false),
  ('uploaded', 'Uploaded', 20, false),
  ('approved', 'Approved', 30, true),
  ('rejected', 'Rejected', 40, true),
  ('expired', 'Expired', 50, false),
  ('expiring_soon', 'Expiring Soon', 60, false)
on conflict (id) do update
set label = excluded.label,
    sort_order = excluded.sort_order,
    is_terminal = excluded.is_terminal,
    updated_at = now();

with default_document_types (name, sort_order, applies_to) as (
  values
    ('US Club Player Card', 10, array['player', 'inquiry']::public.document_owner_type[]),
    ('USYS Player Card', 20, array['player', 'inquiry']::public.document_owner_type[]),
    ('Birth Certificate', 30, array['player', 'inquiry']::public.document_owner_type[]),
    ('Medical Release', 40, array['player', 'inquiry']::public.document_owner_type[]),
    ('Liability Waiver', 50, array['player', 'inquiry']::public.document_owner_type[]),
    ('US Club Coach Card', 60, array['staff']::public.document_owner_type[]),
    ('USYS Coach Card', 70, array['staff']::public.document_owner_type[]),
    ('SafeSport', 80, array['staff']::public.document_owner_type[]),
    ('Background Check', 90, array['staff']::public.document_owner_type[]),
    ('Coaching License', 100, array['staff']::public.document_owner_type[]),
    ('Club Agreement', 110, array['player', 'staff', 'inquiry']::public.document_owner_type[]),
    ('US Club Team Roster', 120, array['team', 'tournament']::public.document_owner_type[]),
    ('USYS Team Roster', 130, array['team', 'tournament']::public.document_owner_type[]),
    ('League Roster', 140, array['team']::public.document_owner_type[]),
    ('Tournament Roster', 150, array['team', 'tournament']::public.document_owner_type[]),
    ('Tournament Check-In Packet', 160, array['team', 'tournament']::public.document_owner_type[]),
    ('Game Card', 170, array['match']::public.document_owner_type[]),
    ('Hotel/Travel Info', 180, array['team', 'tournament']::public.document_owner_type[])
)
insert into public.document_types (name, sort_order, applies_to, is_default)
select d.name, d.sort_order, d.applies_to, true
from default_document_types d
where not exists (
  select 1
  from public.document_types existing
  where existing.club_id is null
    and existing.deleted_at is null
    and lower(existing.name) = lower(d.name)
);

commit;
