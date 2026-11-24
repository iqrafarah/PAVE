-- Wider default evidence types (see docs/verificatie.md).
--
-- The defaults of 20261124130000 were too narrow: a learner could not ask Coolblue to confirm a certificate, while a
-- company also hands out certificates (VCA, BHV, its own training), badges, and reads a reflection on an internship.
-- Only a diploma belongs to education. So now:
--
--   school       every kind of evidence
--   company      every kind except diplomas
--   government   every kind except diplomas
--   other        every kind except diplomas
--
-- Existing contact persons get the kinds that are new for their kind of organisation. Nothing is taken away, and a
-- kind an administrator took away from someone is not put back (only the kinds that are new here are added).
-- Exceptions per person stay in organization_contact_evidence_types. Safe to run again.

-- 1. The defaults ------------------------------------------------------------------------------------------------------

insert into public.organization_kind_evidence_types (kind, category)
select k.kind, c.category
from (values ('school'), ('company'), ('government'), ('other')) as k (kind)
cross join (values
  ('diplomas'), ('certificates'), ('badges'), ('projects'), ('workExperience'),
  ('internships'), ('skills'), ('feedback'), ('reflections'), ('other')
) as c (category)
where c.category <> 'diplomas' or k.kind = 'school'
on conflict do nothing;

-- 2. Existing contact persons: only the kinds that are new for their kind of organisation ------------------------------

insert into public.organization_contact_evidence_types (contact_id, category)
select c.id, added.category
from public.organization_contacts c
join public.organization_departments d on d.id = c.department_id
join public.organization_locations l on l.id = d.location_id
join public.organizations o on o.id = l.organization_id
join (values
  ('school', 'workExperience'), ('school', 'internships'), ('school', 'other'),
  ('company', 'certificates'), ('company', 'badges'), ('company', 'reflections'), ('company', 'other'),
  ('government', 'badges'), ('government', 'reflections'), ('government', 'other'),
  ('other', 'badges'), ('other', 'workExperience'), ('other', 'internships'), ('other', 'reflections')
) as added (kind, category) on added.kind = o.kind
on conflict do nothing;
