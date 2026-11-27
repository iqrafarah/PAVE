-- Test accounts for trying verification as it goes in real life: learners who ask, and persons at schools and
-- companies who confirm. Not a migration. Run it in the Supabase SQL editor after filling in the three values below.
-- Running it again changes nothing that is already there; test_accounts_remove.sql takes everything out again.
--
-- Every address is your own address with a +tag (you+coolblue@gmail.com), so all mail arrives in your own inbox.
--
--   Learners      Noor Jansen (+noor), Daan de Wit (+daan)
--   Reviewers     Mila de Vries     Stagebegeleider  Coolblue · Breda · Stage            (+coolblue)
--                 Thomas Bakker     HR-adviseur      Coolblue · Breda · HR               (+coolbluehr)
--                 Sanne Visser      Teamleider       Albert Heijn · Tilburg · HR         (+ah)
--                 Kevin Smits       Stagedocent      Fontys Hogeschool · Tilburg · ICT   (+fontys)
--                 Lotte Hendriks    Docent           Avans Hogeschool · Breda · ICT      (+avans)
--                 Jesse van Dijk    Crew trainer     McDonald's · Reeshof, Tilburg · HR  (+macreeshof)
--   Both          Emma Peters       Shiftleider      McDonald's · Centrum, Tilburg · HR, and asks for her own evidence (+emma)
--
-- Two McDonald's in Tilburg (Centrum and Reeshof), to try choosing between locations in one city: the script names the
-- existing one "Centrum" and adds "Reeshof". Needs migration 20261124170000_named_locations.sql first.
--
-- Two-step verification: with shared_totp_secret filled in, every test account gets the same authenticator, so one
-- entry in Passwords (Wachtwoorden) gives the code for all of them. Leave it empty to set it up per account at the
-- first sign-in. Only for test accounts: never give real accounts a shared secret.

begin;

do $$
declare
  your_email constant text := 'jouwnaam@gmail.com';   -- your own address; the accounts become jouwnaam+tag@gmail.com
  test_password constant text := 'PaveTest!2026';     -- the password of every test account
  shared_totp_secret constant text := 'PKLX4BTQNWWFKVVUTEWMD6GB5VEORU7P';  -- empty ('') to set it up per account

  local_part text := split_part(your_email, '@', 1);
  domain text := split_part(your_email, '@', 2);
  person record;
  account uuid;
  address text;
  place record;
begin
  if your_email = 'jouwnaam@gmail.com' or domain = '' then
    raise exception 'Vul bovenaan je eigen e-mailadres in.';
  end if;

  -- Two McDonald's in Tilburg: the existing location becomes "Centrum", and "Reeshof" comes next to it.
  update public.organization_locations l set name = 'Centrum'
  from public.organizations o
  where o.id = l.organization_id and o.name = 'McDonald''s' and l.city = 'Tilburg' and l.name is null;
  insert into public.organization_locations (organization_id, city, name)
  select o.id, 'Tilburg', 'Reeshof' from public.organizations o where o.name = 'McDonald''s'
  on conflict do nothing;
  insert into public.organization_departments (location_id, name)
  select l.id, d.name
  from public.organization_locations l
  join public.organizations o on o.id = l.organization_id and o.name = 'McDonald''s'
  cross join (values ('Stage'), ('HR')) as d (name)
  where l.city = 'Tilburg' and l.name = 'Reeshof'
  on conflict do nothing;

  for person in select * from (values
    -- tag,           name,             job title,         organisation,         city,      location,  department
    ('noor',        'Noor Jansen',    null,              null,                 null,      null,      null),
    ('daan',        'Daan de Wit',    null,              null,                 null,      null,      null),
    ('coolblue',    'Mila de Vries',  'Stagebegeleider', 'Coolblue',           'Breda',   null,      'Stage'),
    ('coolbluehr',  'Thomas Bakker',  'HR-adviseur',     'Coolblue',           'Breda',   null,      'HR'),
    ('ah',          'Sanne Visser',   'Teamleider',      'Albert Heijn',       'Tilburg', null,      'HR'),
    ('fontys',      'Kevin Smits',    'Stagedocent',     'Fontys Hogeschool',  'Tilburg', null,      'ICT'),
    ('avans',       'Lotte Hendriks', 'Docent',          'Avans Hogeschool',   'Breda',   null,      'ICT'),
    ('emma',        'Emma Peters',    'Shiftleider',     'McDonald''s',        'Tilburg', 'Centrum', 'HR'),
    ('macreeshof',  'Jesse van Dijk', 'Crew trainer',    'McDonald''s',        'Tilburg', 'Reeshof', 'HR')
  ) as list (tag, name, job_title, organization, city, location, department)
  loop
    address := lower(local_part || '+' || person.tag || '@' || domain);

    -- 1. The account, confirmed, with a password. The profile follows from the trigger on auth.users.
    select id into account from auth.users where lower(email) = address;
    if account is null then
      account := gen_random_uuid();
      insert into auth.users (
        instance_id, id, aud, role, email, encrypted_password, email_confirmed_at,
        raw_app_meta_data, raw_user_meta_data, created_at, updated_at,
        confirmation_token, recovery_token, email_change_token_new, email_change
      ) values (
        '00000000-0000-0000-0000-000000000000', account, 'authenticated', 'authenticated', address,
        extensions.crypt(test_password, extensions.gen_salt('bf')), now(),
        '{"provider":"email","providers":["email"]}', jsonb_build_object('full_name', person.name), now(), now(),
        '', '', '', ''
      );
      insert into auth.identities (id, user_id, provider_id, provider, identity_data, last_sign_in_at, created_at, updated_at)
      values (
        gen_random_uuid(), account, account::text, 'email',
        jsonb_build_object('sub', account::text, 'email', address, 'email_verified', true), now(), now(), now()
      );
    end if;
    update public.profiles set full_name = coalesce(full_name, person.name) where id = account;

    -- 2. The shared authenticator, when there is none yet.
    if shared_totp_secret <> '' and not exists (
      select 1 from auth.mfa_factors f where f.user_id = account and f.factor_type = 'totp' and f.status = 'verified'
    ) then
      delete from auth.mfa_factors where user_id = account and status = 'unverified';
      insert into auth.mfa_factors (id, user_id, friendly_name, factor_type, status, secret, created_at, updated_at)
      values (gen_random_uuid(), account, 'PAVE test', 'totp', 'verified', shared_totp_secret, now(), now());
    end if;

    -- 3. A reviewer: the person at the organisation, linked to the account. The trigger gives the default set of
    --    evidence they may confirm.
    if person.organization is not null then
      select d.id as department_id into place
      from public.organizations o
      join public.organization_locations l on l.organization_id = o.id and l.city = person.city
        and l.name is not distinct from person.location
      join public.organization_departments d on d.location_id = l.id and d.name = person.department
      where o.name = person.organization
      limit 1;
      if place.department_id is null then
        raise exception 'Niet gevonden: % · % % · %', person.organization, coalesce(person.location || ', ', ''), person.city, person.department;
      end if;
      insert into public.organization_contacts (department_id, name, job_title, reviewer_id)
      values (place.department_id, person.name, person.job_title, account)
      on conflict (department_id, name)
      do update set reviewer_id = excluded.reviewer_id, job_title = excluded.job_title, is_active = true;
    end if;
  end loop;
end $$;

commit;

-- Who is who now:
select o.name as organisatie, concat_ws(', ', l.name, l.city) as vestiging, d.name as afdeling, c.name as persoon, c.job_title as functie,
       u.email as account
from public.organization_contacts c
join public.organization_departments d on d.id = c.department_id
join public.organization_locations l on l.id = d.location_id
join public.organizations o on o.id = l.organization_id
join auth.users u on u.id = c.reviewer_id
order by 1, 2, 3, 4;
