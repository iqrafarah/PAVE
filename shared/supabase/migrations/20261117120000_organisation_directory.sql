-- The organisations a learner can pick when asking for verification, with the places each one has.
-- `organizations` itself belongs to the web team (id, name, created_at, logo_url); this adds what the pick-list needs:
-- a kind, and one row per place. Only trusted server code writes them. Learners may read them to fill in the form, but
-- what a learner types or picks never decides who may review a request (that stays vault_validation_reviewers).

alter table public.organizations
  add column if not exists kind text check (kind is null or kind in ('school', 'company'));
comment on column public.organizations.kind is 'school (onderwijsinstelling) or company (bedrijf); null when not set.';

create table if not exists public.organization_locations (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations (id) on delete cascade,
  city text not null check (length(btrim(city)) between 1 and 100),
  created_at timestamptz not null default now(),
  unique (organization_id, city)
);

create index if not exists organization_locations_organization on public.organization_locations (organization_id);

alter table public.organization_locations enable row level security;
drop policy if exists "Signed-in users can read organisation locations" on public.organization_locations;
create policy "Signed-in users can read organisation locations"
  on public.organization_locations for select to authenticated
  using (true);
grant select on public.organization_locations to authenticated;
revoke insert, update, delete on public.organization_locations from authenticated;
revoke all on public.organization_locations from anon;

-- The list. An organisation that already exists (same name, ignoring case and spaces) is kept and only gets its kind and
-- places; the others are added. Safe to run again.
do $$
declare
  entry record;
  v_id uuid;
  v_city text;
begin
  for entry in
    select * from (values
    ('Fontys Hogeschool', 'school', array['Tilburg', 'Eindhoven', 'Den Bosch', 'Venlo', 'Sittard']),
    ('Avans Hogeschool', 'school', array['Breda', 'Tilburg', 'Den Bosch', 'Roosendaal']),
    ('Yonder', 'school', array['Tilburg']),
    ('Curio', 'school', array['Breda', 'Roosendaal', 'Bergen op Zoom', 'Oosterhout']),
    ('De Rooi Pannen', 'school', array['Tilburg', 'Breda', 'Eindhoven']),
    ('Summa', 'school', array['Eindhoven']),
    ('Koning Willem I College', 'school', array['Den Bosch', 'Oss', 'Veghel', 'Cuijk']),
    ('Yuverta', 'school', array['Tilburg', 'Eindhoven', 'Den Bosch', 'Helmond']),
    ('Breda University of Applied Sciences', 'school', array['Breda']),
    ('Tilburg University', 'school', array['Tilburg']),
    ('Technische Universiteit Eindhoven', 'school', array['Eindhoven']),
    ('HAS green academy', 'school', array['Den Bosch', 'Venlo']),
    ('SintLucas', 'school', array['Eindhoven', 'Boxtel']),
    ('Ter AA', 'school', array['Helmond', 'Deurne']),
    ('ROC Nijmegen', 'school', array['Nijmegen', 'Boxmeer']),
    ('Coolblue', 'company', array['Tilburg', 'Breda', 'Eindhoven', 'Den Bosch']),
    ('Albert Heijn', 'company', array['Tilburg', 'Breda', 'Eindhoven', 'Den Bosch', 'Waalwijk', 'Roosendaal']),
    ('Jumbo', 'company', array['Tilburg', 'Breda', 'Eindhoven', 'Den Bosch', 'Veghel']),
    ('IKEA', 'company', array['Breda', 'Eindhoven']),
    ('bol', 'company', array['Waalwijk', 'Utrecht']),
    ('ASML', 'company', array['Veldhoven', 'Eindhoven']),
    ('Philips', 'company', array['Eindhoven', 'Best']),
    ('DAF Trucks', 'company', array['Eindhoven', 'Geldrop']),
    ('VDL Groep', 'company', array['Eindhoven', 'Tilburg', 'Helmond']),
    ('CM.com', 'company', array['Breda']),
    ('Prodrive Technologies', 'company', array['Son en Breugel']),
    ('Heijmans', 'company', array['Rosmalen', 'Eindhoven']),
    ('McDonald''s', 'company', array['Tilburg', 'Breda', 'Eindhoven', 'Den Bosch']),
    ('Kruidvat', 'company', array['Tilburg', 'Breda', 'Eindhoven', 'Den Bosch']),
    ('HEMA', 'company', array['Tilburg', 'Breda', 'Eindhoven', 'Den Bosch']),
    ('Decathlon', 'company', array['Tilburg', 'Breda', 'Eindhoven']),
    ('PostNL', 'company', array['Tilburg', 'Breda', 'Eindhoven', 'Den Bosch']),
    ('DHL', 'company', array['Tilburg', 'Eindhoven', 'Breda']),
    ('Elisabeth-TweeSteden Ziekenhuis', 'company', array['Tilburg', 'Waalwijk']),
    ('Amphia', 'company', array['Breda', 'Oosterhout']),
    ('Jeroen Bosch Ziekenhuis', 'company', array['Den Bosch']),
    ('Organon', 'company', array['Oss'])
    ) as list(name, kind, cities)
  loop
    select id into v_id from public.organizations where lower(btrim(name)) = lower(btrim(entry.name)) order by created_at limit 1;
    if v_id is null then
      insert into public.organizations (name, kind) values (entry.name, entry.kind) returning id into v_id;
    else
      update public.organizations set kind = coalesce(kind, entry.kind) where id = v_id;
    end if;
    foreach v_city in array entry.cities loop
      insert into public.organization_locations (organization_id, city) values (v_id, v_city)
      on conflict (organization_id, city) do nothing;
    end loop;
  end loop;
end $$;
