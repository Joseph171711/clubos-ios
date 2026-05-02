-- Safe founding DOC bootstrap for Atletico Dallas.
--
-- Use only after the founding user exists in Supabase Auth.
-- Replace FOUNDING_USER_EMAIL with the exact email shown in Auth > Users.
-- This script does not create auth.users rows and does not require any
-- passwords, service role keys, or direct connection strings to be stored.

do $$
declare
  v_founder_email text := lower('FOUNDING_USER_EMAIL');
  v_user_count integer;
  v_user_id uuid;
  v_user_email text;
  v_club_id uuid;
  v_profile_id uuid;
begin
  if v_founder_email = 'founding_user_email' then
    raise exception 'Replace FOUNDING_USER_EMAIL with the founding Auth user email before running this script.';
  end if;

  select count(*)
  into v_user_count
  from auth.users
  where lower(email) = v_founder_email;

  if v_user_count = 0 then
    raise exception 'No Supabase Auth user found for %.', v_founder_email;
  end if;

  if v_user_count > 1 then
    raise exception 'Multiple Supabase Auth users found for %. Resolve duplicates before bootstrapping.', v_founder_email;
  end if;

  select id, email
  into v_user_id, v_user_email
  from auth.users
  where lower(email) = v_founder_email
  limit 1;

  select id
  into v_club_id
  from public.clubs
  where slug = 'atletico-dallas'
    and deleted_at is null;

  if v_club_id is null then
    raise exception 'Atletico Dallas club row is missing. Apply bootstrap_atletico_dallas_foundation first.';
  end if;

  select id
  into v_profile_id
  from public.profiles
  where user_id = v_user_id
    and deleted_at is null
  limit 1;

  if v_profile_id is null then
    insert into public.profiles (
      user_id,
      club_id,
      role,
      first_name,
      last_name,
      email,
      is_active
    )
    values (
      v_user_id,
      v_club_id,
      'doc',
      'Joseph',
      'Paez',
      v_user_email,
      true
    )
    returning id into v_profile_id;
  else
    update public.profiles
    set
      club_id = v_club_id,
      role = 'doc',
      first_name = 'Joseph',
      last_name = 'Paez',
      email = v_user_email,
      is_active = true,
      deleted_at = null,
      updated_at = now()
    where id = v_profile_id;
  end if;

  raise notice 'Founding DOC profile bootstrapped. profile_id=%, auth_user_id=%, club_id=%',
    v_profile_id,
    v_user_id,
    v_club_id;
end;
$$;
