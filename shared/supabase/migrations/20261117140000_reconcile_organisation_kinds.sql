-- Correct stale non-null categories left behind by the original organisation-directory seed.
-- That migration used coalesce(kind, entry.kind), which preserved any pre-existing wrong kind.
-- This only classifies the organisations in the trusted directory seed; unrelated rows remain untouched.
with directory(organization_name, expected_kind) as (
  values
    ('Fontys Hogeschool', 'school'),
    ('Avans Hogeschool', 'school'),
    ('Yonder', 'school'),
    ('Curio', 'school'),
    ('De Rooi Pannen', 'school'),
    ('Summa', 'school'),
    ('Koning Willem I College', 'school'),
    ('Yuverta', 'school'),
    ('Breda University of Applied Sciences', 'school'),
    ('Tilburg University', 'school'),
    ('Technische Universiteit Eindhoven', 'school'),
    ('HAS green academy', 'school'),
    ('SintLucas', 'school'),
    ('Ter AA', 'school'),
    ('ROC Nijmegen', 'school'),
    ('Coolblue', 'company'),
    ('Albert Heijn', 'company'),
    ('Jumbo', 'company'),
    ('IKEA', 'company'),
    ('bol', 'company'),
    ('ASML', 'company'),
    ('Philips', 'company'),
    ('DAF Trucks', 'company'),
    ('VDL Groep', 'company'),
    ('CM.com', 'company'),
    ('Prodrive Technologies', 'company'),
    ('Heijmans', 'company'),
    ('McDonald''s', 'company'),
    ('Kruidvat', 'company'),
    ('HEMA', 'company'),
    ('Decathlon', 'company'),
    ('PostNL', 'company'),
    ('DHL', 'company'),
    ('Elisabeth-TweeSteden Ziekenhuis', 'company'),
    ('Amphia', 'company'),
    ('Jeroen Bosch Ziekenhuis', 'company'),
    ('Organon', 'company')
)
update public.organizations as organization
set kind = directory.expected_kind
from directory
where lower(btrim(organization.name)) = lower(btrim(directory.organization_name))
  and organization.kind is distinct from directory.expected_kind;
