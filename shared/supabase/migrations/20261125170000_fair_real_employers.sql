-- Real employers for the job fair demo in the presentation: two in IT and three of other kinds (care, retail and a
-- municipality), each with real vacancies read from the employer's own career site on 25 November 2026. They do not
-- take part in PAVE; the app and the site say so, with the day the vacancies were read (created_at). Vacancies change:
-- each links to the original. The summaries are our own words. Can be run again.

insert into public.fair_employers (slug, name, city, about, stand, website, is_example, vacancies) values
  ('ogd', 'OGD ict-diensten', 'Eindhoven',
   'OGD levert ict-diensten op het gebied van infrastructuur, werkplekbeheer en softwareontwikkeling, met vestigingen in Delft, Eindhoven, Enschede en Utrecht.',
   'Stand A', 'ogd.nl', false,
   '[{"id":"fair-ogd-traineeship","title":"Traineeship IT","company":"OGD ict-diensten","employment":"fullTime","source":"web","url":"https://werkenbij.ogd.nl/vacatures/traineeship-it","summary":"Twee jaar als trainee in de ict: je begint met een maand bootcamp en werkt daarna op de servicedesk bij een klant. Daarna kies je een richting, zoals systeembeheer of consultancy. Vanaf 32 uur, minimaal een hbo-propedeuse.","matches":[],"skillGap":[]}]'::jsonb),
  ('sioux-technologies', 'Sioux Technologies', 'Eindhoven',
   'Sioux combineert software, elektronica, mechanica en wiskunde voor bedrijven met high-tech projecten, zoals in de chip- en medische industrie.',
   'Stand B', 'sioux.eu', false,
   '[{"id":"fair-sioux-software","title":"Software Engineer C#/C++/Java","company":"Sioux Technologies","city":"Eindhoven","employment":"fullTime","source":"web","url":"https://vacancy.sioux.eu/vacancies/vacancy_software_engineer_c_c_java_343474_31.html","summary":"Je bouwt applicatiesoftware in C#, C++ of Java voor high-tech klanten en werkt agile met reviews en tests. Ze vragen een bachelor of master informatica en 2 tot 3 jaar ervaring.","matches":[],"skillGap":[]}]'::jsonb),
  ('catharina-ziekenhuis', 'Catharina Ziekenhuis', 'Eindhoven',
   'Het Catharina Ziekenhuis is een topklinisch opleidingsziekenhuis in Eindhoven met ruim 4.000 medewerkers.',
   'Stand C', 'catharinaziekenhuis.nl', false,
   '[{"id":"fair-catharina-msmh","title":"Medewerker Steriele Medische Hulpmiddelen","company":"Catharina Ziekenhuis","city":"Eindhoven","source":"web","url":"https://werkenbij.catharinaziekenhuis.nl/vacatures/medewerker-steriele-medische-hulpmiddelen-msmh-parttime-of-fulltime/","summary":"Je maakt chirurgische instrumenten en endoscopen schoon, controleert en steriliseert ze, zodat de operatieteams veilig kunnen werken. 16 tot 36 uur, mbo-opleiding MSMH.","matches":[],"skillGap":[]},{"id":"fair-catharina-zorgassistent","title":"Zorgassistent Flexbureau","company":"Catharina Ziekenhuis","city":"Eindhoven","employment":"partTime","source":"web","url":"https://werkenbij.catharinaziekenhuis.nl/vacatures/zorgassistent-flexbureau-parttime/","summary":"Je helpt patiënten op verschillende afdelingen met basiszorg en maaltijden, samen met verpleegkundigen en diëtisten. Tot 30 uur, contract voor zeven maanden, mbo-niveau.","matches":[],"skillGap":[]}]'::jsonb),
  ('jumbo', 'Jumbo', 'Veghel',
   'Jumbo is een supermarktketen met een hoofdkantoor in Veghel en een eigen bezorgservice.',
   'Stand D', 'jumbo.com', false,
   '[{"id":"fair-jumbo-planning","title":"Medewerker Planning & Support (bijbaan)","company":"Jumbo","city":"Veghel","employment":"partTime","source":"web","url":"https://nl.jobs.jumbo.com/nl/vacature/medewerker-planning-support/2026-34794/","summary":"Je ondersteunt de bezorgers onderweg, past routes aan en beantwoordt vragen en klachten van klanten. 12,5 tot 17 uur per week, minimaal op zaterdag en één avond.","matches":[],"skillGap":[]}]'::jsonb),
  ('gemeente-eindhoven', 'Gemeente Eindhoven', 'Eindhoven',
   'De gemeente Eindhoven werkt aan de stad, onder meer aan het nieuwe stationsgebied rond Eindhoven Centraal.',
   'Stand E', 'eindhoven.nl', false,
   '[{"id":"fair-eindhoven-stedenbouw","title":"Stagiair Stedenbouw","company":"Gemeente Eindhoven","city":"Eindhoven","source":"web","url":"https://www.werkenvooreindhoven.nl/vacature/stagiair-stedenbouw-0","summary":"Een meewerkstage vanaf februari bij het team dat het gebied rond Eindhoven Centraal ontwikkelt, met analyses, ontwerpend onderzoek en kaarten. Voor een wo-studie stedenbouw of architectuur; reageren kon tot 27 november 2026.","matches":[],"skillGap":[]}]'::jsonb)
on conflict (slug) do update set
  name = excluded.name, city = excluded.city, about = excluded.about, stand = excluded.stand, website = excluded.website,
  is_example = excluded.is_example, vacancies = excluded.vacancies;
