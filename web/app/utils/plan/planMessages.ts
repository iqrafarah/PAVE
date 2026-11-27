import type { PlanStepKind, PlanStepStatus } from '~/types/plan';

// The words of the plans, the same as on iOS (PlanMessages, PlanStepKind+Look; docs/ui-teksten.md).

export const PLAN_TITLE = 'Plan';
export const PLAN_EMPTY_TITLE = 'Je hebt nog geen plan';
export const PLAN_EMPTY_MESSAGE = 'Maak een plan voor een doel waar je naartoe wilt werken. Ayla helpt je stap voor stap.';
export const PLAN_NEW = 'Nieuw plan';
export const PLAN_CREATE = 'Maken';
export const PLAN_SAVE = 'Bewaren';
export const PLAN_CANCEL = 'Annuleren';
export const PLAN_EDIT = 'Plan aanpassen';
export const PLAN_RENAME = 'Naam aanpassen';
export const PLAN_NAME_LABEL = 'Naam';
export const PLAN_NAME_PLACEHOLDER = 'Bijvoorbeeld: Doorgroeien naar teamleider';
export const PLAN_GOAL_LABEL = 'Doel';
export const PLAN_GOAL_HINT = 'Waar wil je naartoe werken? Ayla gebruikt dit in de gesprekken van dit plan.';
export const PLAN_GOAL_PLACEHOLDER = 'Wat wil je bereiken?';
export const PLAN_START_LABEL = 'Beginnen met';
export const PLAN_DELETE = 'Plan verwijderen';
export const PLAN_DELETE_QUESTION = 'Plan verwijderen?';
export const PLAN_DELETE_BODY = 'De stappen van dit plan verdwijnen. Bewijs in je kluis blijft altijd bewaard.';
export const PLAN_DELETE_BODY_CHATS = (chats: number) =>
  `De stappen van dit plan verdwijnen. ${chats === 1 ? 'Het gesprek' : `De ${chats} gesprekken`} met Ayla van dit plan ${chats === 1 ? 'komt' : 'komen'} in je gewone chats. Bewijs in je kluis blijft altijd bewaard.`;
export const PLAN_COMPLETE = 'Voltooien';
export const PLAN_REOPEN = 'Weer openen';
export const PLAN_ACTIVE_SECTION = 'Actief';
export const PLAN_FINISHED_SECTION = 'Voltooid';
export const PLAN_SAVE_FAILED = 'Je plan kon niet worden bewaard. Probeer het nog eens.';
export const PLAN_LOAD_FAILED = 'Je plannen konden niet worden geladen.';
export const PLAN_NOT_AVAILABLE = 'Plannen zijn nog niet beschikbaar. Probeer het later nog eens.';
export const PLAN_LOADING = 'Laden…';
export const PLAN_RETRY = 'Opnieuw proberen';
export const PLAN_KIND_LABEL = 'Soort stap';
export const PLAN_SKIPPED_NOTE = 'Overgeslagen stappen tellen niet mee.';
export const PLAN_STEPS = 'Stappen';
export const PLAN_NO_STEPS = 'Dit plan heeft nog geen stappen.';
export const PLAN_ADD_STEP = 'Stap toevoegen';
export const PLAN_PROPOSE_STEPS = 'Laat Ayla stappen voorstellen';
export const PLAN_PROPOSAL_TITLE = 'Voorstel van Ayla';
export const PLAN_PROPOSAL_THINKING = 'Ayla denkt na over je stappen…';
export const PLAN_PROPOSAL_FAILED = 'Ayla kon nu geen stappen voorstellen. Probeer het opnieuw.';
export const PLAN_PROPOSAL_AGAIN = 'Probeer opnieuw';
export const PLAN_PROPOSAL_OTHERS = 'Andere stappen voorstellen';
export const PLAN_PROPOSAL_EMPTY =
  'Ayla heeft geen nieuwe stappen voor dit plan. Vul je doel aan en probeer het opnieuw, of voeg zelf een stap toe.';
export const PLAN_PROPOSAL_ADD = (count: number) => (count === 1 ? 'Voeg 1 stap toe' : `Voeg ${count} stappen toe`);
export function planProposalReads(evidence: number, hasVacancy: boolean) {
  const seen =
    evidence === 0
      ? 'Ze ziet geen bewijs uit je kluis: daar gaf je geen toestemming voor.'
      : `Van je kluis ziet ze alleen de titels van de ${evidence === 1 ? '1 bewijsstuk' : `${evidence} bewijsstukken`} die ze mag bekijken.`;
  return `Ayla gebruikt de naam en het doel van je plan${hasVacancy ? ' en de vacature waar het om gaat' : ''}. ${seen} Er wordt niets toegevoegd tot jij kiest.`;
}
export const PLAN_VACANCY_MAKE = 'Maak een plan voor deze vacature';
export const PLAN_VACANCY_OPEN = 'Open je plan voor deze vacature';
export function planVacancyHint(missing: number) {
  if (missing === 0) return 'Stappen van de vacature lezen tot het gesprek oefenen.';
  return `Met een stap voor ${missing === 1 ? 'wat je nog mist' : `elk van de ${Math.min(missing, 3)} dingen die je nog mist`}, je cv en brief, en het gesprek.`;
}
export const PLAN_PRACTISE_TALK = 'Oefen het gesprek met Ayla';
export const PLAN_PROJECT = 'Project';
export const PLAN_NO_PROJECT = 'Geen project';
export const PLAN_LINK_PROJECT = 'Koppel aan een project';
export const PLAN_LINK_PROJECT_HINT = 'De gesprekken van dit plan komen dan in dat project en gebruiken de instructies en bronnen ervan.';
export const PLAN_LINKED_PROJECT_HINT = 'De gesprekken van dit plan staan in dit project en gebruiken de instructies en bronnen ervan.';
export const PLAN_PROJECT_PLAN = 'Plan in dit project';
export const PLAN_PROJECT_PLANS = 'Plannen in dit project';
export const PLAN_WITH_AYLA_TITLE = 'Stappen van Ayla';
export const PLAN_WITH_AYLA_SUMMARY = 'Ayla stelt stappen voor bij je doel. Jij kiest welke je houdt.';
export const PLAN_EMPTY_TEMPLATE_TITLE = 'Leeg plan';
export const PLAN_EMPTY_TEMPLATE_SUMMARY = 'Begin met een doel en voeg zelf stappen toe.';
export const PLAN_STEP_TITLE_LABEL = 'Stap';
export const PLAN_STEP_TITLE_PLACEHOLDER = 'Wat ga je doen?';
export const PLAN_STEP_SUMMARY_LABEL = 'Omschrijving';
export const PLAN_STEP_SUMMARY_PLACEHOLDER = 'Een korte uitleg (mag leeg blijven)';
export const PLAN_EDIT_STEP = 'Stap aanpassen';
export const PLAN_DELETE_STEP = 'Stap verwijderen';
export const PLAN_MARK_DONE = 'Afronden';
export const PLAN_MARK_ACTIVE = 'Hier verder';
export const PLAN_MARK_UPCOMING = 'Nog te doen';
export const PLAN_MARK_SKIPPED = 'Overslaan';
export const PLAN_MOVE_UP = 'Omhoog';
export const PLAN_MOVE_DOWN = 'Omlaag';
export const PLAN_DISCUSS_STEP = 'Bespreken met Ayla';
export const PLAN_OPEN_STEP_CHAT = 'Gesprek van deze stap openen';
export const PLAN_DETACH_CONVERSATION = 'Uit plan halen';
export const PLAN_IN_PLAN = (name: string) => `Nu: ${name}`;
export const PLAN_FINISHED = 'Klaar! Je hebt alle stappen afgerond.';
export const PLAN_CONVERSATIONS = 'Gesprekken met Ayla';
export const PLAN_NO_CONVERSATIONS = 'Nog geen gesprekken in dit plan.';
export const PLAN_NEW_CONVERSATION = 'Nieuw gesprek';
export const PLAN_RESUME = 'Verder met Ayla';
export const PLAN_OPEN = 'Open plan';
export const PLAN_BACK = 'Terug naar je plannen';
export const PLAN_MORE = 'Meer';
export const PLAN_STEP_ACTIONS = (title: string) => `Wat wil je doen met ${title}?`;
export const PLAN_PROGRESS = (done: number, total: number) => `${done} van ${total}`;
export const PLAN_PROGRESS_DONE = (done: number, total: number) => `${done} van ${total} afgerond`;
export const PLAN_STEP_NUMBER = (current: number, total: number) => `Stap ${current} van ${total}`;
export const PLAN_STEP_COUNT = (count: number) => (count === 1 ? '1 stap' : `${count} stappen`);
export const PLAN_CONVERSATION_COUNT = (count: number) => (count === 1 ? '1 gesprek' : `${count} gesprekken`);
export const PLAN_STEP_PROMPT = (title: string) => `Help me met de stap "${title}".`;
export const PLAN_UNTITLED_CONVERSATION = (index: number) => `Gesprek ${index}`;

export const PLAN_STATUS: Record<PlanStepStatus, string> = {
  upcoming: 'nog te doen',
  active: 'nu bezig',
  done: 'afgerond',
  skipped: 'overgeslagen',
};

/** The kinds the user can choose for a step of their own. */
export const PLAN_CHOOSABLE_KINDS: PlanStepKind[] = [
  'general', 'conversation', 'research', 'evidence', 'verification', 'document', 'profile', 'contact', 'action', 'reflection', 'milestone',
];

const KIND_TITLES: Record<string, string> = {
  conversation: 'Gesprek met Ayla',
  research: 'Uitzoeken',
  evidence: 'Bewijs in je kluis',
  verification: 'Laten verifiëren',
  document: 'Schrijven',
  action: 'Zelf doen',
  reflection: 'Terugkijken',
  milestone: 'Mijlpaal',
  profile: 'Profiel',
  contact: 'Contact',
};

/** "Uitzoeken", or "Algemeen" for a kind the app does not know. */
export function planKindTitle(kind: PlanStepKind) {
  return KIND_TITLES[kind] ?? 'Algemeen';
}

// The place in PAVE where a kind of step is done, besides talking it through with Ayla (iOS destination).
const KIND_PLACES: Record<string, { path: string; label: string }> = {
  evidence: { path: '/kluis', label: 'Open je kluis' },
  verification: { path: '/kluis', label: 'Open je kluis' },
  profile: { path: '/profiel', label: 'Open je profiel' },
  contact: { path: '/meldingen', label: 'Open Meldingen' },
};

export function planKindPlace(kind: PlanStepKind) {
  return KIND_PLACES[kind] ?? null;
}

// The steps of a plan for a vacancy (iOS PlanVacancy.template).
export const PLAN_VACANCY_STEPS = {
  read: 'Lees de vacature goed',
  readSummary: 'Kijk wat ze vragen en wat je daarvan al kunt laten zien.',
  workOn: (skill: string) => `Werk aan ${skill}`,
  asks: (requirement: string) => `De vacature vraagt: ${requirement}`,
  missing: 'De vacature vraagt hierom en het staat nog niet in je kluis.',
  evidence: 'Zet passend bewijs in je kluis',
  evidenceSummary: 'Voeg toe wat bij deze vacature hoort en laat het verifiëren waar dat kan.',
  write: 'Schrijf je cv en brief',
  writeSummary: 'Maak ze voor deze vacature; Ayla schrijft mee met wat ze van je mag zien.',
  share: 'Deel je sollicitatie',
  shareSummary: (company: string) => `Kies wat ${company} mag zien en hoe lang.`,
  practise: 'Oefen het gesprek met Ayla',
  practiseSummary: 'Bereid je voor op de vragen die je kunt verwachten.',
  templateSummary: 'Stappen naar een sollicitatie.',
  goal: (title: string, company: string) => `Solliciteren op ${title} bij ${company}.`,
};
