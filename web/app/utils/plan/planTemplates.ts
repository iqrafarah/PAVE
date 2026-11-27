import type { PlanTemplate } from '~/types/plan';
import { PLAN_EMPTY_TEMPLATE_SUMMARY, PLAN_EMPTY_TEMPLATE_TITLE, PLAN_WITH_AYLA_SUMMARY, PLAN_WITH_AYLA_TITLE } from './planMessages';

// The templates a plan can start with (iOS PlanTemplates; keep them the same). Each step is a kind that leads
// somewhere in PAVE. The user can change, add, remove and skip every step afterwards.

const job: PlanTemplate = {
  id: 'job',
  name: 'Een baan vinden',
  summary: 'Van wat je zoekt tot je eerste werkdag.',
  goal: 'Een baan vinden die bij me past.',
  steps: [
    { title: 'Wat voor werk zoek je?', summary: 'Bespreek met Ayla wat je zoekt: soort werk, uren en plek.', kind: 'conversation' },
    { title: 'Je profiel bijwerken', summary: 'Laat in je profiel zien wie je bent en wat je kunt.', kind: 'profile' },
    { title: 'Bewijs in je kluis', summary: "Zet diploma's, certificaten en werkervaring in je kluis.", kind: 'evidence' },
    { title: 'Vacatures zoeken', summary: 'Zoek samen met Ayla vacatures die bij je passen.', kind: 'research' },
    { title: 'Solliciteren', summary: 'Schrijf je motivatie en stuur je sollicitatie.', kind: 'document' },
    { title: 'Contact houden', summary: 'Houd bij wie je hebt gesproken en wat je terughoort.', kind: 'contact' },
    { title: 'Je gesprek voorbereiden', summary: 'Oefen je sollicitatiegesprek met Ayla.', kind: 'conversation' },
  ],
};

const internship: PlanTemplate = {
  id: 'internship',
  name: 'Een stage vinden',
  summary: 'Een stageplek die past bij je opleiding.',
  goal: 'Een stage vinden waar ik veel leer.',
  steps: [
    { title: 'Wat wil je leren?', summary: 'Bespreek met Ayla wat je in je stage wilt leren.', kind: 'conversation' },
    { title: 'Eisen van je opleiding', summary: 'Zoek uit wat je opleiding van een stage vraagt.', kind: 'research' },
    { title: 'Je profiel bijwerken', summary: 'Zet je opleiding en wat je al kunt in je profiel.', kind: 'profile' },
    { title: 'Stageplekken zoeken', summary: 'Zoek met Ayla bedrijven die stages bieden.', kind: 'research' },
    { title: 'Overleggen met je begeleider', summary: 'Bespreek je keuze met je stagebegeleider van school.', kind: 'contact' },
    { title: 'Solliciteren', summary: 'Schrijf je motivatie en stuur je sollicitatie.', kind: 'document' },
    { title: 'Stageovereenkomst regelen', summary: 'Leg de afspraken vast met school en je stageplek.', kind: 'milestone' },
  ],
};

const career: PlanTemplate = {
  id: 'career',
  name: 'Mijn loopbaan ontdekken',
  summary: 'Ontdek welke richting bij je past.',
  goal: 'Ontdekken welk werk bij me past.',
  steps: [
    { title: 'Wat geeft je energie?', summary: 'Praat met Ayla over wat je leuk vindt en belangrijk.', kind: 'conversation' },
    { title: 'Je sterke punten', summary: 'Kijk met Ayla naar wat je al kunt, ook in je kluis.', kind: 'reflection' },
    { title: 'Richtingen verkennen', summary: 'Zoek een paar richtingen die je aanspreken.', kind: 'research' },
    { title: 'Praten met iemand uit het vak', summary: 'Vraag iemand naar diens werk en ervaring.', kind: 'contact' },
    { title: 'Een richting kiezen', summary: 'Kies de richting waar je mee verder gaat.', kind: 'milestone' },
    { title: 'Je volgende stap plannen', summary: 'Maak met Ayla een plan voor die richting.', kind: 'conversation' },
  ],
};

const education: PlanTemplate = {
  id: 'education',
  name: 'Een vervolgopleiding kiezen',
  summary: 'Van oriënteren tot aanmelden.',
  goal: 'Een opleiding kiezen die bij me past.',
  steps: [
    { title: 'Wat wil je worden?', summary: 'Bespreek met Ayla wat je interesseert en wat je wilt.', kind: 'conversation' },
    { title: 'Opleidingen vergelijken', summary: 'Zet een paar opleidingen naast elkaar.', kind: 'research' },
    { title: 'Toelatingseisen checken', summary: 'Kijk welk diploma en welke vakken je nodig hebt.', kind: 'research' },
    { title: 'Open dag of meeloopdag', summary: 'Ga kijken en praat met studenten en docenten.', kind: 'action' },
    { title: "Diploma's in je kluis", summary: "Zet je diploma's en cijferlijsten in je kluis.", kind: 'evidence' },
    { title: 'Aanmelden', summary: 'Meld je op tijd aan voor je opleiding.', kind: 'milestone' },
  ],
};

const skill: PlanTemplate = {
  id: 'skill',
  name: 'Een vaardigheid ontwikkelen',
  summary: 'Leer iets nieuws en laat zien dat je het kunt.',
  goal: 'Een vaardigheid leren en laten zien dat ik die beheers.',
  steps: [
    { title: 'Je doel scherp krijgen', summary: 'Bespreek met Ayla wat je wilt leren en waarom.', kind: 'conversation' },
    { title: 'Wat je al kunt', summary: 'Kijk terug op wat je al hebt gedaan en geleerd.', kind: 'reflection' },
    { title: 'Leren en oefenen', summary: 'Zoek een cursus, project of manier om te oefenen.', kind: 'research' },
    { title: 'Bewijs in je kluis', summary: 'Bewaar een project, resultaat of feedback.', kind: 'evidence' },
    { title: 'Laten verifiëren', summary: 'Vraag iemand om je bewijs te bevestigen.', kind: 'verification' },
    { title: 'Je profiel bijwerken', summary: 'Zet de vaardigheid in je profiel.', kind: 'profile' },
  ],
};

const certificate: PlanTemplate = {
  id: 'certificate',
  name: 'Een certificaat behalen',
  summary: 'Van kiezen tot een geverifieerd certificaat.',
  goal: 'Een certificaat halen dat me verder helpt.',
  steps: [
    { title: 'Het juiste certificaat kiezen', summary: 'Bespreek met Ayla welk certificaat bij je doel past.', kind: 'conversation' },
    { title: 'Inschrijven', summary: 'Schrijf je in voor de cursus of het examen.', kind: 'action' },
    { title: 'Een studieplanning maken', summary: 'Maak met Ayla een planning tot het examen.', kind: 'conversation' },
    { title: 'Leren en oefenen', summary: 'Werk de stof door en oefen met proefexamens.', kind: 'research' },
    { title: 'Het examen', summary: 'De dag van je examen.', kind: 'milestone' },
    { title: 'Certificaat in je kluis', summary: 'Zet je certificaat in je kluis.', kind: 'evidence' },
    { title: 'Laten verifiëren', summary: 'Laat de uitgever je certificaat bevestigen.', kind: 'verification' },
    { title: 'Je profiel bijwerken', summary: 'Zet het certificaat in je profiel.', kind: 'profile' },
  ],
};

const careerSwitch: PlanTemplate = {
  id: 'switch',
  name: 'Een carrièreswitch maken',
  summary: 'Stap over naar ander werk, met wat je al kunt.',
  goal: 'Overstappen naar werk dat beter bij me past.',
  steps: [
    { title: 'Waarom wil je switchen?', summary: 'Bespreek met Ayla wat je zoekt en wat je achterlaat.', kind: 'conversation' },
    { title: 'Wat neem je mee?', summary: 'Breng je ervaring en vaardigheden in kaart.', kind: 'reflection' },
    { title: 'Een nieuwe richting verkennen', summary: 'Zoek uit welk werk bij je past.', kind: 'research' },
    { title: 'Praten met mensen uit het vak', summary: 'Vraag hoe het werk echt is en hoe zij erin kwamen.', kind: 'contact' },
    { title: 'Wat je nog mist', summary: 'Bespreek met Ayla welke kennis of certificaten je nodig hebt.', kind: 'conversation' },
    { title: 'Bijscholen', summary: 'Volg een cursus of opleiding voor je nieuwe vak.', kind: 'research' },
    { title: 'Profiel en kluis bijwerken', summary: 'Laat zien wat je meeneemt en wat je erbij leerde.', kind: 'profile' },
    { title: 'Solliciteren', summary: 'Solliciteer in je nieuwe vak.', kind: 'document' },
  ],
};

export const EMPTY_PLAN_TEMPLATE: PlanTemplate = { id: 'empty', name: '', summary: '', goal: '', steps: [] };
/** No steps yet: once the plan is made, Ayla proposes them and the user picks. */
export const WITH_AYLA_TEMPLATE: PlanTemplate = { id: 'with-ayla', name: '', summary: PLAN_WITH_AYLA_SUMMARY, goal: '', steps: [] };

/** What "Nieuw plan" offers, the empty one first. */
export const PLAN_TEMPLATES: PlanTemplate[] = [EMPTY_PLAN_TEMPLATE, WITH_AYLA_TEMPLATE, job, internship, career, education, skill, certificate, careerSwitch];

const TEMPLATE_ICONS: Record<string, string> = {
  job: '/images/vault/icons/BriefcaseSolid.svg',
  vacancy: '/images/vault/icons/BriefcaseSolid.svg',
  internship: '/images/vault/icons/BuildingOfficeSolid.svg',
  career: '/images/vault/icons/RocketLaunchSolid.svg',
  education: '/images/vault/icons/AcademicCapSolid.svg',
  skill: '/images/vault/icons/WrenchScrewdriverSolid.svg',
  certificate: '/images/vault/icons/CheckBadgeSolid.svg',
  switch: '/images/vault/icons/ArrowPath.svg',
  empty: '/images/vault/icons/Plus.svg',
  'with-ayla': '/images/plan/conversation.svg',
};

/** The icon of a template, and of a plan that started from it. */
export function planTemplateIcon(templateId: string | null | undefined) {
  return TEMPLATE_ICONS[templateId ?? ''] ?? '/images/plan/general.svg';
}

const KIND_ICONS = ['conversation', 'research', 'evidence', 'verification', 'document', 'action', 'reflection', 'milestone', 'profile', 'contact'];

/** The icon of a kind of step, all from the filled family; an unknown kind looks like a general step. */
export function planStepIcon(kind: string) {
  return `/images/plan/${KIND_ICONS.includes(kind) ? kind : 'general'}.svg`;
}

/** "Leeg plan" and "Stappen van Ayla" have no name of their own. */
export function planTemplateTitle(template: PlanTemplate) {
  if (template.id === WITH_AYLA_TEMPLATE.id) return PLAN_WITH_AYLA_TITLE;
  return template.steps.length ? template.name : PLAN_EMPTY_TEMPLATE_TITLE;
}

export function planTemplateSummary(template: PlanTemplate) {
  if (template.id === WITH_AYLA_TEMPLATE.id) return PLAN_WITH_AYLA_SUMMARY;
  return template.steps.length ? template.summary : PLAN_EMPTY_TEMPLATE_SUMMARY;
}
