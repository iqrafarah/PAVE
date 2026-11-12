import type { VaultItemCategory } from '~/types/vault';

// "Kluis aanvullen" (Figma FEDDIES 1167:12715, 1167:11759, 1167:12237, 1167:11255, 1167:10880). The category names and
// the checks match iOS (VaultCategory.swift, VaultItemDraft.swift and VaultMessages.swift).

export const VAULT_ADD_TITLE = 'Kluis aanvullen';
export const VAULT_ADD_QUESTION = 'Wil je iets toevoegen?';
export const VAULT_ADD_YES = 'Ja';
export const VAULT_ADD_NO = 'Nee';
export const VAULT_ADD_CLOSE = 'Sluiten';
export const VAULT_ADD_NEXT = 'Volgende';
export const VAULT_ADD_BACK = 'Terug';
export const VAULT_ADD_SAVING = 'Bezig met opslaan…';
export const VAULT_ADD_STEPS = ['Basis', 'Documenten', 'Vaardigheden', 'Afronden'] as const;

export const VAULT_DROP_FILE = 'Sleep bestand hierheen of klik om te uploaden';
export const VAULT_OR = 'Of';
export const VAULT_WITHOUT_FILE_TITLE = 'Voeg een ervaring toe zonder bestand';
export const VAULT_WITHOUT_FILE_MESSAGE = 'Geen document, geen probleem. Je kunt ook zelf ervaringen toevoegen.';
export const VAULT_REMOVE_FILE = 'Bestand weghalen';

export const VAULT_FIELD_TITLE = 'Titel';
export const VAULT_FIELD_CATEGORY = 'Soort bewijs';
export const VAULT_FIELD_CATEGORY_PLACEHOLDER = 'Kies een soort';
export const VAULT_FIELD_ORGANISATION = 'Organisatie / school';
export const VAULT_FIELD_PERIOD = 'Periode';
export const VAULT_FIELD_ISSUED = 'Behaald in';
export const VAULT_FIELD_START = 'Van';
export const VAULT_FIELD_END = 'Tot';
export const VAULT_FIELD_END_HINT = 'Leeg als je dit nog doet';
export const VAULT_FIELD_DESCRIPTION = 'Beschrijving';
export const VAULT_REQUIRED = 'verplicht';

export const VAULT_COVER = 'Omslag';
export const VAULT_NO_COVER = 'Geen Omslag';

export const VAULT_SKILLS_FROM_VAULT = 'Vaardigheden uit mijn kluis';
export const VAULT_SKILLS_FROM_AYLA = 'Voorstel van';
export const VAULT_SKILLS_ADD_OWN = 'Zelf een vaardigheid toevoegen';
export const VAULT_SKILLS_SEARCH = 'Zoek een vaardigheid of voeg er zelf een toe';
export const VAULT_SKILLS_NONE_IN_VAULT = 'Er staan nog geen vaardigheden in je kluis.';
export const VAULT_SKILLS_NONE_FROM_AYLA = 'Ayla heeft nog geen voorstel voor dit bewijs.';
export const VAULT_SKILLS_SELECTED = 'Gekozen vaardigheden';
export const VAULT_SKILL_ADD = 'Toevoegen';
export const VAULT_SKILL_REMOVE = 'Weghalen';
export const VAULT_SKILL_ADD_TYPED = (name: string) => `“${name}” toevoegen`;

export const VAULT_DONE_TITLE = 'Bewijs toegevoegd';
export const VAULT_DONE_CONSENT = 'Ayla mag dit document bekijken en gebruiken';
export const VAULT_DONE_FINISH = 'Afronden';

export const VAULT_DISCARD_TITLE = 'Stoppen met toevoegen? Wat je hebt ingevuld, wordt niet bewaard.';
export const VAULT_DISCARD_CONFIRM = 'Stoppen';

export const VAULT_PROBLEM_TITLE = 'Geef het bewijs een titel.';
export const VAULT_PROBLEM_TITLE_TOO_LONG = 'De titel mag maximaal 200 tekens zijn.';
export const VAULT_PROBLEM_CATEGORY = 'Kies wat voor bewijs dit is.';
export const VAULT_PROBLEM_ORGANISATION = 'Vul de organisatie of school in.';
export const VAULT_PROBLEM_PERIOD = 'Vul in wanneer dit was.';
export const VAULT_PROBLEM_END_BEFORE_START = 'De einddatum ligt voor de begindatum.';
export const VAULT_PROBLEM_DESCRIPTION = 'Vertel kort wat je hebt gedaan of geleerd.';
export const VAULT_PROBLEM_DESCRIPTION_TOO_LONG = 'De omschrijving is te lang.';
export const VAULT_PROBLEM_FILE = 'Kies een bestand, of voeg een ervaring toe zonder bestand.';
export const VAULT_PROBLEM_COVER = 'Kies een afbeelding voor de omslag, of kies Geen Omslag.';
export const VAULT_FILE_TOO_BIG = 'Dit bestand is groter dan 20 MB. Kies een kleiner bestand.';
export const VAULT_FILE_TYPE = 'Dit soort bestand kan niet in je kluis. Kies een PDF, Word-bestand, foto of tekstbestand.';
export const VAULT_COVER_TYPE = 'Kies een JPG-, PNG- of HEIC-afbeelding.';
export const VAULT_FILE_EMPTY = 'Dit bestand is leeg.';

export const VAULT_SAVE_FAILED = 'Je bewijs kon niet worden opgeslagen. Probeer het zo nog een keer.';
export const VAULT_SAVE_NOT_SIGNED_IN = 'Je sessie is verlopen. Log opnieuw in om je kluis aan te vullen.';
export const VAULT_SAVE_NOT_READY = 'Je kluis is nog niet beschikbaar. Probeer het later nog een keer.';
export const VAULT_CONSENT_FAILED = 'Je toestemming kon niet worden opgeslagen. Probeer het opnieuw.';

export const VAULT_CATEGORY_TITLES: Record<VaultItemCategory, string> = {
  diplomas: 'Diploma',
  certificates: 'Certificaat',
  badges: 'Badge',
  projects: 'Project',
  workExperience: 'Werkervaring',
  internships: 'Stage',
  skills: 'Vaardigheid',
  feedback: 'Feedback',
  reflections: 'Reflectie',
  other: 'Overig',
};

/** Obtained on one day (a date), or done for a while (a start and an end), as on iOS. */
export function hasPeriod(category: VaultItemCategory | '') {
  return !['diplomas', 'certificates', 'badges'].includes(category);
}

/** "PDF - 2,4 MB", as under the file in the design. */
export function describeFile(file: File) {
  const extension = file.name.split('.').pop()?.toUpperCase() ?? '';
  const megabytes = file.size / 1024 / 1024;
  const size = megabytes >= 1
    ? `${megabytes.toLocaleString('nl-NL', { maximumFractionDigits: 1 })} MB`
    : `${Math.max(1, Math.round(file.size / 1024))} KB`;
  return extension ? `${extension} - ${size}` : size;
}
