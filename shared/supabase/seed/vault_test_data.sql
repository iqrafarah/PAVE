-- Test data for the vault of one test account, for trying the apps and the demo (scenario 3: Ravi, ICT student).
--
-- Not a migration: it only adds rows for one account. Run it in the Supabase SQL editor with the e-mail address of the
-- test account filled in below. Running it again replaces the test data; vault_test_data_remove.sql takes it out again.
-- Only rows whose id starts with 5eed0000 are touched, so the account's own items and folders stay as they are.
--
-- What it gives you: 15 items in every category, all three statuses (Geverifieerd, Niet bevestigd, Afgewezen), every
-- source (zelf, organisatie, Ayla, geïmporteerd), current and finished periods, skills, items Ayla may and may not use,
-- the four example folders (reused when the account has them) and two folders of its own. No files: those need the
-- Storage API.

begin;

-- The guard on vault_items lets only trusted server code add confirmed items or items from an organisation, and this
-- script is that code. The role is set for this transaction only.
select set_config('request.jwt.claims', '{"role":"service_role"}', true);
select set_config('request.jwt.claim.role', 'service_role', true);

do $$
declare
  test_email constant text := 'vul-hier-het-e-mailadres-in@example.com';
  target uuid;
  folder_certificates uuid;
  folder_diplomas uuid;
  folder_feedback uuid;
  folder_projects uuid;
  folder_graduation uuid;
  folder_jobs uuid;
begin
  select id into target from auth.users where lower(email) = lower(test_email);
  if target is null then
    raise exception 'Geen account met het e-mailadres %. Vul bovenaan het e-mailadres van het testaccount in.', test_email;
  end if;

  delete from public.vault_items where user_id = target and id::text like '5eed0000-%';
  delete from public.vault_folders where user_id = target and id::text like '5eed0000-%';

  -- Folders: the four example folders, reused when the account already has them, and two of its own.
  select id into folder_certificates from public.vault_folders where user_id = target and lower(name) = 'certificaten';
  if folder_certificates is null then
    insert into public.vault_folders (id, user_id, name, color, icon)
    values ('5eed0000-0000-4000-8000-100000000001', target, 'Certificaten', 'green', 'check-badge')
    returning id into folder_certificates;
  end if;

  select id into folder_diplomas from public.vault_folders where user_id = target and lower(name) = 'diploma''s';
  if folder_diplomas is null then
    insert into public.vault_folders (id, user_id, name, color, icon)
    values ('5eed0000-0000-4000-8000-100000000002', target, 'Diploma''s', 'green', 'academic-cap')
    returning id into folder_diplomas;
  end if;

  select id into folder_feedback from public.vault_folders where user_id = target and lower(name) = 'feedback';
  if folder_feedback is null then
    insert into public.vault_folders (id, user_id, name, color, icon)
    values ('5eed0000-0000-4000-8000-100000000003', target, 'Feedback', 'green', 'chat-bubble-left-ellipsis')
    returning id into folder_feedback;
  end if;

  select id into folder_projects from public.vault_folders where user_id = target and lower(name) = 'projecten';
  if folder_projects is null then
    insert into public.vault_folders (id, user_id, name, color, icon)
    values ('5eed0000-0000-4000-8000-100000000004', target, 'Projecten', 'green', 'wrench-screwdriver')
    returning id into folder_projects;
  end if;

  select id into folder_graduation from public.vault_folders where user_id = target and lower(name) = 'afstuderen';
  if folder_graduation is null then
    insert into public.vault_folders (id, user_id, name, color, icon)
    values ('5eed0000-0000-4000-8000-100000000005', target, 'Afstuderen', 'blue', 'rocket-launch')
    returning id into folder_graduation;
  end if;

  select id into folder_jobs from public.vault_folders where user_id = target and lower(name) = 'bijbanen';
  if folder_jobs is null then
    insert into public.vault_folders (id, user_id, name, color, icon)
    values ('5eed0000-0000-4000-8000-100000000006', target, 'Bijbanen', 'rust', 'briefcase')
    returning id into folder_jobs;
  end if;

  -- Items. created_at is spread out, so "Nieuwste eerst" and "Oudste eerst" give a clear order.
  insert into public.vault_items (
    id, user_id, folder_id, category, title, description, organisation_name, organisation_location,
    start_date, end_date, issued_on, is_current, verification_status, source, ayla_allowed_at, created_at, updated_at
  ) values
    ('5eed0000-0000-4000-8000-000000000001', target, folder_diplomas, 'diplomas', 'Propedeuse HBO-ICT',
     'Eerste jaar van de bachelor HBO-ICT afgerond, met de profielen software en media.',
     'Fontys Hogescholen', 'Eindhoven', null, null, '2024-07-12', false, 'verified', 'organization',
     now() - interval '20 days', now() - interval '480 days', now() - interval '480 days'),
    ('5eed0000-0000-4000-8000-000000000002', target, folder_diplomas, 'diplomas', 'Vwo-diploma',
     'Natuur en Techniek, met informatica als keuzevak.',
     'Stedelijk College Eindhoven', 'Eindhoven', null, null, '2022-07-08', false, 'verified', 'organization',
     null, now() - interval '900 days', now() - interval '900 days'),
    ('5eed0000-0000-4000-8000-000000000003', target, folder_certificates, 'certificates', 'Microsoft Azure Fundamentals (AZ-900)',
     'Online examen over de basis van cloud: diensten, beveiliging en kosten in Azure.',
     'Microsoft', 'Online', null, null, '2025-03-21', false, 'verified', 'import',
     now() - interval '20 days', now() - interval '600 days', now() - interval '600 days'),
    ('5eed0000-0000-4000-8000-000000000004', target, folder_certificates, 'certificates', 'Cambridge English C1 Advanced',
     'Engels op C1-niveau: lezen, schrijven, luisteren en spreken.',
     'Cambridge English', 'Eindhoven', null, null, '2023-06-15', false, 'toVerify', 'user',
     null, now() - interval '700 days', now() - interval '700 days'),
    ('5eed0000-0000-4000-8000-000000000005', target, folder_graduation, 'internships', 'Afstudeerstage iOS-ontwikkelaar',
     'Ik bouw een iOS-app in SwiftUI voor de klanten van Pixelwerk, van onderzoek tot een geteste versie.',
     'Pixelwerk', 'Eindhoven', '2026-09-01', null, null, true, 'toVerify', 'user',
     now() - interval '10 days', now() - interval '70 days', now() - interval '70 days'),
    ('5eed0000-0000-4000-8000-000000000006', target, null, 'internships', 'Meewerkstage webdevelopment',
     'Websites gebouwd in Vue en TypeScript voor kleine ondernemers in Tilburg.',
     'Studio Noord', 'Tilburg', '2025-02-03', '2025-06-27', null, false, 'rejected', 'user',
     null, now() - interval '500 days', now() - interval '500 days'),
    ('5eed0000-0000-4000-8000-000000000007', target, folder_jobs, 'workExperience', 'Teamleider avondploeg',
     'Ik plan de avonddiensten, werk nieuwe collega''s in en ben het aanspreekpunt als de manager er niet is.',
     'Supermarkt De Hoek', 'Tilburg', '2025-11-01', null, null, true, 'toVerify', 'user',
     now() - interval '30 days', now() - interval '370 days', now() - interval '370 days'),
    ('5eed0000-0000-4000-8000-000000000008', target, folder_jobs, 'workExperience', 'Medewerker ICT-servicedesk',
     'Studenten en docenten geholpen met accounts, wifi en printen, aan de balie en via de chat.',
     'Fontys ICT Services', 'Eindhoven', '2023-09-01', '2024-08-31', null, false, 'verified', 'organization',
     null, now() - interval '800 days', now() - interval '800 days'),
    ('5eed0000-0000-4000-8000-000000000009', target, folder_projects, 'projects', 'PAVE: portfolio-app met AI-assistent',
     'Met mijn team bouw ik PAVE voor web en iPhone: een kluis voor je ontwikkeling, met Ayla als assistent.',
     'Fontys Hogescholen', 'Eindhoven', '2026-09-01', null, null, true, 'toVerify', 'user',
     now() - interval '5 days', now() - interval '60 days', now() - interval '60 days'),
    ('5eed0000-0000-4000-8000-000000000010', target, folder_projects, 'projects', 'Smart Campus-dashboard',
     'Een dashboard dat laat zien hoe druk het is in de lokalen, met data van sensoren op de campus.',
     'Fontys Hogescholen', 'Eindhoven', '2025-02-10', '2025-06-20', null, false, 'verified', 'organization',
     now() - interval '20 days', now() - interval '510 days', now() - interval '510 days'),
    ('5eed0000-0000-4000-8000-000000000011', target, folder_feedback, 'feedback', 'Feedback stagebegeleider Pixelwerk',
     '"Ravi stelt goede vragen en denkt mee over wat de klant echt nodig heeft. Volgende stap: vaker zelf het voortouw nemen in overleg."',
     'Pixelwerk', 'Eindhoven', null, null, '2026-10-30', false, 'toVerify', 'ayla',
     null, now() - interval '14 days', now() - interval '14 days'),
    ('5eed0000-0000-4000-8000-000000000012', target, null, 'reflections', 'Reflectie: van developer naar consultant?',
     'Ik merk dat ik het leukst vind om met klanten te praten over wat ze nodig hebben. Misschien past een rol als IT-consultant beter bij me dan alleen programmeren.',
     null, null, null, null, '2026-10-02', false, 'toVerify', 'user',
     now() - interval '5 days', now() - interval '42 days', now() - interval '42 days'),
    ('5eed0000-0000-4000-8000-000000000013', target, null, 'badges', 'Brainport Hackathon 2025: tweede plaats',
     'In 48 uur een prototype gebouwd dat lege laadpalen in de buurt laat zien.',
     'Brainport Development', 'Eindhoven', null, null, '2025-04-12', false, 'verified', 'import',
     null, now() - interval '580 days', now() - interval '580 days'),
    ('5eed0000-0000-4000-8000-000000000014', target, null, 'skills', 'Presenteren voor opdrachtgevers',
     'Elke sprintreview presenteer ik ons werk aan de opdrachtgever, ook in het Engels.',
     null, null, null, null, null, false, 'toVerify', 'user',
     null, now() - interval '25 days', now() - interval '25 days'),
    ('5eed0000-0000-4000-8000-000000000015', target, null, 'other', 'Rijbewijs B',
     'Handig voor stages en klantbezoeken buiten Eindhoven.',
     'CBR', 'Eindhoven', null, null, '2023-03-03', false, 'toVerify', 'user',
     null, now() - interval '950 days', now() - interval '950 days');

  -- An item can be in more than one folder once migration 20261112130000 is applied; before that, folder_id above counts.
  if to_regclass('public.vault_item_folders') is not null then
    insert into public.vault_item_folders (user_id, item_id, folder_id)
    select target, id, folder_id from public.vault_items
    where user_id = target and id::text like '5eed0000-%' and folder_id is not null;

    insert into public.vault_item_folders (user_id, item_id, folder_id) values
      (target, '5eed0000-0000-4000-8000-000000000009', folder_graduation),
      (target, '5eed0000-0000-4000-8000-000000000011', folder_graduation);
  end if;

  -- Skills, the way "Vaardigheden" saves them: accepted, by the user, by Ayla or from the organisation.
  insert into public.vault_item_skills (user_id, item_id, name, source, status) values
    (target, '5eed0000-0000-4000-8000-000000000001', 'Programmeren', 'organization', 'accepted'),
    (target, '5eed0000-0000-4000-8000-000000000001', 'Samenwerken', 'organization', 'accepted'),
    (target, '5eed0000-0000-4000-8000-000000000001', 'Analyseren', 'organization', 'accepted'),
    (target, '5eed0000-0000-4000-8000-000000000002', 'Wiskunde', 'organization', 'accepted'),
    (target, '5eed0000-0000-4000-8000-000000000002', 'Engels', 'organization', 'accepted'),
    (target, '5eed0000-0000-4000-8000-000000000003', 'Cloud', 'import', 'accepted'),
    (target, '5eed0000-0000-4000-8000-000000000003', 'Azure', 'import', 'accepted'),
    (target, '5eed0000-0000-4000-8000-000000000004', 'Engels', 'user', 'accepted'),
    (target, '5eed0000-0000-4000-8000-000000000005', 'Swift', 'user', 'accepted'),
    (target, '5eed0000-0000-4000-8000-000000000005', 'SwiftUI', 'user', 'accepted'),
    (target, '5eed0000-0000-4000-8000-000000000005', 'Testen', 'ayla', 'accepted'),
    (target, '5eed0000-0000-4000-8000-000000000005', 'Communicatie', 'ayla', 'accepted'),
    (target, '5eed0000-0000-4000-8000-000000000006', 'Vue', 'user', 'accepted'),
    (target, '5eed0000-0000-4000-8000-000000000006', 'TypeScript', 'user', 'accepted'),
    (target, '5eed0000-0000-4000-8000-000000000007', 'Leiderschap', 'user', 'accepted'),
    (target, '5eed0000-0000-4000-8000-000000000007', 'Communicatie', 'user', 'accepted'),
    (target, '5eed0000-0000-4000-8000-000000000007', 'Planning', 'ayla', 'accepted'),
    (target, '5eed0000-0000-4000-8000-000000000008', 'Klantcontact', 'organization', 'accepted'),
    (target, '5eed0000-0000-4000-8000-000000000008', 'Probleemoplossing', 'organization', 'accepted'),
    (target, '5eed0000-0000-4000-8000-000000000009', 'SwiftUI', 'user', 'accepted'),
    (target, '5eed0000-0000-4000-8000-000000000009', 'Supabase', 'user', 'accepted'),
    (target, '5eed0000-0000-4000-8000-000000000009', 'UX-onderzoek', 'ayla', 'accepted'),
    (target, '5eed0000-0000-4000-8000-000000000009', 'Samenwerken', 'user', 'accepted'),
    (target, '5eed0000-0000-4000-8000-000000000010', 'Vue', 'organization', 'accepted'),
    (target, '5eed0000-0000-4000-8000-000000000010', 'TypeScript', 'organization', 'accepted'),
    (target, '5eed0000-0000-4000-8000-000000000010', 'Datavisualisatie', 'organization', 'accepted'),
    (target, '5eed0000-0000-4000-8000-000000000011', 'Communicatie', 'ayla', 'accepted'),
    (target, '5eed0000-0000-4000-8000-000000000012', 'Zelfreflectie', 'user', 'accepted'),
    (target, '5eed0000-0000-4000-8000-000000000013', 'Pitchen', 'import', 'accepted'),
    (target, '5eed0000-0000-4000-8000-000000000013', 'Prototypen', 'import', 'accepted'),
    (target, '5eed0000-0000-4000-8000-000000000014', 'Presenteren', 'user', 'accepted');

  raise notice 'Testdata toegevoegd aan de kluis van %: 15 items, 6 mappen (bestaande voorbeeldmappen hergebruikt).', test_email;
end;
$$;

commit;
