-- The verification form asks for one person, but the demo directory from 20261117130000 only had roles and desks
-- ("Stagebureau", "Stagebegeleider", "HR-afdeling", "Docent ICT"). This adds demo persons with a name and a function,
-- and takes the role rows out of the pick-list.
--
-- The names are made up: demo persons, not real staff. Real teachers and contact persons are added by the team and
-- linked to their PAVE account in organization_contact_reviewers. A person without such a link routes the request to
-- the organisation's assigned reviewers (vault_validation_recipients), so these demo persons work for testing.
-- Safe to run again: names follow from the organisation id, and existing rows are left alone.

-- 1. Role rows leave the list. Rows linked to a reviewer account stay, so test routing that uses them keeps working.
update public.organization_contacts c
set is_active = false
where c.is_active
  and (c.name in ('Stagebureau', 'Stagebegeleider', 'HR-afdeling')
       or c.name ~ '^(Stagecoördinator|Docent) (ICT|Engineering|Pedagogiek)$')
  and not exists (select 1 from public.organization_contact_reviewers cr where cr.contact_id = c.id);

-- 2. Demo persons: two per organisation, and two per Fontys department.
create or replace function pg_temp.demo_person(p_seed text)
returns text
language sql
immutable
as $$
  select (array['Sanne', 'Daan', 'Fatima', 'Lucas', 'Noor', 'Milan', 'Yara', 'Sem', 'Eva', 'Mohamed',
                'Lotte', 'Jesse', 'Amira', 'Thijs', 'Femke', 'Bram', 'Ilse', 'Ruben', 'Zeynep', 'Tim'])
           [1 + abs(hashtext(p_seed)::bigint) % 20]
      || ' ' ||
         (array['de Vries', 'Jansen', 'Bakker', 'Visser', 'Smit', 'Meijer', 'de Boer', 'Mulder', 'de Groot', 'Bos',
                'Vos', 'Peters', 'Hendriks', 'van Dijk', 'Dekker', 'Brouwer', 'van Leeuwen', 'Kaya', 'El Amrani', 'Verhoeven'])
           [1 + abs(hashtext(p_seed || ':achternaam')::bigint) % 20];
$$;

do $$
declare
  v_org record;
  v_department record;
  v_function text;
begin
  for v_org in select id, kind from public.organizations where kind is not null loop
    foreach v_function in array (case when v_org.kind = 'school'
                                      then array['Docent', 'Stagecoördinator']
                                      else array['Stagebegeleider', 'HR-adviseur'] end) loop
      insert into public.organization_contacts (organization_id, name, job_title)
      values (v_org.id, pg_temp.demo_person(v_org.id::text || ':' || v_function), v_function)
      on conflict (organization_id, location_id, department_id, name) do nothing;
    end loop;
  end loop;

  for v_department in
    select d.id, d.organization_id from public.organization_departments d
    join public.organizations o on o.id = d.organization_id
    where lower(btrim(o.name)) = 'fontys hogeschool'
  loop
    foreach v_function in array array['Docent', 'Stagecoördinator'] loop
      insert into public.organization_contacts (organization_id, department_id, name, job_title)
      values (v_department.organization_id, v_department.id,
              pg_temp.demo_person(v_department.id::text || ':' || v_function), v_function)
      on conflict (organization_id, location_id, department_id, name) do nothing;
    end loop;
  end loop;
end $$;

comment on table public.organization_contacts is
  'People a learner can ask to confirm evidence, each with a function. Demo rows are made-up persons; real staff are added by the team.';
