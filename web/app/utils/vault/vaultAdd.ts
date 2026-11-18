import type { AylaReply } from '~/types/ayla';
import type { VaultItemDraft } from '~/types/vault';
import {
  VAULT_COVER_TYPE,
  VAULT_FILE_EMPTY,
  VAULT_FILE_TOO_BIG,
  VAULT_FILE_TYPE,
  VAULT_ADD_NO,
  VAULT_ADD_QUESTION,
  VAULT_ADD_YES,
  VAULT_PROBLEM_CATEGORY,
  VAULT_PROBLEM_DESCRIPTION,
  VAULT_PROBLEM_DESCRIPTION_TOO_LONG,
  VAULT_PROBLEM_END_BEFORE_START,
  VAULT_PROBLEM_ORGANISATION,
  VAULT_PROBLEM_PERIOD,
  VAULT_PROBLEM_TITLE,
  VAULT_PROBLEM_TITLE_TOO_LONG,
  hasPeriod,
} from './vaultMessages';

// What the pave-vault bucket and vault_item_files accept (shared/supabase/migrations/20261110120000_vault.sql).
export const MAX_VAULT_FILE_BYTES = 20 * 1024 * 1024;
const MAX_TITLE_LENGTH = 200;
const MAX_DESCRIPTION_LENGTH = 10000;

const MIME_BY_EXTENSION: Record<string, string> = {
  pdf: 'application/pdf',
  doc: 'application/msword',
  docx: 'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
  heic: 'image/heic',
  jpg: 'image/jpeg',
  jpeg: 'image/jpeg',
  png: 'image/png',
  txt: 'text/plain',
};
const COVER_EXTENSIONS = ['jpg', 'jpeg', 'png', 'heic'];

export const VAULT_FILE_ACCEPT = Object.keys(MIME_BY_EXTENSION).map((extension) => `.${extension}`).join(',');
export const VAULT_COVER_ACCEPT = COVER_EXTENSIONS.map((extension) => `.${extension}`).join(',');

export function getExtension(fileName: string) {
  return fileName.split('.').pop()?.toLowerCase() ?? '';
}

/** The type the database allows for this file. Browsers often give HEIC no type, so the extension decides. */
export function getVaultMimeType(file: File) {
  return MIME_BY_EXTENSION[getExtension(file.name)] ?? null;
}

/** Why this file cannot go into the vault, or null. */
export function checkVaultFile(file: File, kind: 'evidence' | 'cover') {
  const extension = getExtension(file.name);
  if (kind === 'cover' && !COVER_EXTENSIONS.includes(extension)) return VAULT_COVER_TYPE;
  if (!getVaultMimeType(file)) return VAULT_FILE_TYPE;
  if (file.size === 0) return VAULT_FILE_EMPTY;
  if (file.size > MAX_VAULT_FILE_BYTES) return VAULT_FILE_TOO_BIG;
  return null;
}

export function createDraft(): VaultItemDraft {
  return {
    title: '',
    category: '',
    organisationName: '',
    startMonth: '',
    endMonth: '',
    issuedMonth: '',
    description: '',
    usesPeriod: null,
  };
}

/** Whether the draft has a period (start and end) or one date: what you chose, or else what fits its kind. */
export function draftHasPeriod(draft: VaultItemDraft) {
  return draft.usesPeriod ?? hasPeriod(draft.category);
}

export type DraftField = 'title' | 'category' | 'organisationName' | 'period' | 'description';

/** Every field that keeps the draft from being saved, with what to say. The design marks all of them as required. */
export function checkDraft(draft: VaultItemDraft): Partial<Record<DraftField, string>> {
  const problems: Partial<Record<DraftField, string>> = {};
  const title = draft.title.trim();
  if (!title) problems.title = VAULT_PROBLEM_TITLE;
  else if (title.length > MAX_TITLE_LENGTH) problems.title = VAULT_PROBLEM_TITLE_TOO_LONG;
  if (!draft.category) problems.category = VAULT_PROBLEM_CATEGORY;
  if (!draft.organisationName.trim()) problems.organisationName = VAULT_PROBLEM_ORGANISATION;
  if (draftHasPeriod(draft)) {
    if (!draft.startMonth) problems.period = VAULT_PROBLEM_PERIOD;
    else if (draft.endMonth && draft.endMonth < draft.startMonth) problems.period = VAULT_PROBLEM_END_BEFORE_START;
  } else if (!draft.issuedMonth) {
    problems.period = VAULT_PROBLEM_PERIOD;
  }
  const description = draft.description.trim();
  if (!description) problems.description = VAULT_PROBLEM_DESCRIPTION;
  else if (description.length > MAX_DESCRIPTION_LENGTH) problems.description = VAULT_PROBLEM_DESCRIPTION_TOO_LONG;
  return problems;
}

function toDate(month: string) {
  return month ? `${month}-01` : null;
}

/** The columns for vault_items, like VaultItemDraft.row on iOS: only the dates that fit the category are sent. */
export function toVaultItemRow(draft: VaultItemDraft) {
  const withPeriod = draftHasPeriod(draft);
  return {
    category: draft.category,
    title: draft.title.trim(),
    description: draft.description.trim() || null,
    organisation_name: draft.organisationName.trim() || null,
    start_date: withPeriod ? toDate(draft.startMonth) : null,
    end_date: withPeriod ? toDate(draft.endMonth) : null,
    issued_on: withPeriod ? null : toDate(draft.issuedMonth),
    // Started and not ended: something you still do ("nov 2025 - nu").
    is_current: withPeriod && Boolean(draft.startMonth) && !draft.endMonth,
  };
}

const ADD_WORDS = /toevoeg|aanvul|bewaar|opsla|\bzet/;

const ADD_EVIDENCE_QUESTION = {
  text: VAULT_ADD_QUESTION,
  choices: [
    { id: 'yes', label: VAULT_ADD_YES },
    { id: 'no', label: VAULT_ADD_NO },
  ],
};

/**
 * Only a request to put something in the vault ("Zet mijn stage in de kluis") gets the offer to add something, besides
 * Ayla offering it herself. Asking what is in the vault does not, and neither does her question whether she may look in
 * it (accessRequest). The same as `AylaVaultOffer` on iOS. `asked` is the user's question this reply answers.
 */
function isVaultQuestion(reply: AylaReply, asked = '') {
  if (reply.question || reply.accessRequest || isAppVaultMessage(asked)) return false;
  if (reply.navigation?.screen === 'addEvidence') return true;
  const question = asked.toLowerCase();
  return question.includes('kluis') && ADD_WORDS.test(question);
}

// A question for words starts with one of these ("Wat wil je toevoegen?"); every other question is one for Ja or Nee.
const OPEN_WORDS = /^(?:wat|welke?|hoe|wanneer|waar\w*|wie|waarom|hoeveel|hoelang)\b/i;

/** The sentences of Ayla's text, each ending at . ! ? or a new line (iOS AylaVaultOffer.sentences). */
function sentences(text: string) {
  const result: string[] = [];
  let current = '';
  for (const character of text) {
    if (character === '\n') {
      result.push(current);
      current = '';
      continue;
    }
    current += character;
    if ('.!?'.includes(character)) {
      result.push(current);
      current = '';
    }
  }
  result.push(current);
  return result.map((sentence) => sentence.trim()).filter(Boolean);
}

/** Ayla's last question in her text, if she asked one. A sentence after it ("Bijvoorbeeld een diploma.") does not count. */
export function lastQuestionSentence(text: string) {
  return sentences(text).findLast((sentence) => sentence.endsWith('?')) ?? null;
}

/**
 * Ayla's last question is one for Ja or Nee: not a question for words ("Wat wil je toevoegen?") and not a choice between
 * things ("Wil je een diploma of een stage toevoegen?"). The same as iOS (endsWithYesNoQuestion).
 */
export function endsWithYesNoQuestion(text: string) {
  const last = lastQuestionSentence(text);
  return Boolean(last) && !OPEN_WORDS.test(last!) && !last!.toLowerCase().includes(' of ');
}

/**
 * The app's own messages to Ayla after something went into the vault ("Toegevoegd aan mijn kluis: …", "Ik heb 1 foto
 * toegevoegd aan …"). Her answer to them is a follow-up about that item, never a new offer to add something.
 */
export function isAppVaultMessage(text: string) {
  return /^(Toegevoegd aan mijn kluis|Ik heb \d+ foto)/.test(text.trim());
}

/** She still asks for something in words in this message ("Wanneer heb je het behaald?"): she is not done asking. */
export function stillAsks(text: string) {
  return sentences(text).some((sentence) => sentence.endsWith('?') && OPEN_WORDS.test(sentence));
}

/** Her last question is whether she may put it in the vault ("Wil je dit diploma toevoegen aan je kluis?"). */
export function asksToPutInVault(reply: AylaReply | null | undefined) {
  if (!reply || reply.accessRequest || stillAsks(reply.text)) return false;
  const last = lastQuestionSentence([reply.text, reply.question?.text].filter(Boolean).join(' '))?.toLowerCase();
  return Boolean(last) && last!.includes('kluis') && ADD_WORDS.test(last!) && !OPEN_WORDS.test(last!);
}

const YES_NO_CHOICES = ADD_EVIDENCE_QUESTION.choices;

const RESERVATIONS = new Set(['nee', 'niet', 'geen', 'wacht', 'eerst', 'aanpassen', 'verander', 'veranderen', 'anders', 'nog', 'toch', 'alleen']);
const CONFIRMATION_STARTS = new Set([
  'ja', 'jazeker', 'graag', 'klopt', 'prima', 'oké', 'oke', 'ok', 'okay', 'top', 'goed', 'perfect', 'zeker', 'natuurlijk', 'yes',
  'akkoord', 'doen', 'doe', 'zet', 'toevoegen', 'bewaar', 'sla', 'mooi',
]);

/**
 * A short typed yes to what Ayla proposed ("Graag", "Zet er maar in", "Ja dat klopt"). Not with a reservation ("ja,
 * maar eerst de datum aanpassen"), a question, or more than a few words (iOS AylaVaultOffer.isConfirmation).
 */
export function isConfirmation(text: string) {
  const words = text.toLowerCase().replace(/[.,!…]+/g, ' ').split(/\s+/).filter(Boolean);
  if (!words.length || words.length > 7 || text.includes('?')) return false;
  if (words.some((word) => RESERVATIONS.has(word)) || (words.length > 1 && words[1] === 'maar')) return false;
  return CONFIRMATION_STARTS.has(words[0]!);
}

/**
 * The question under Ayla's answer, with its choices: her own; "Wil je iets toevoegen?" (Figma 976:7971) when she was
 * asked to add; or Ja and Nee for any question in her words that asks for one of them (as iOS pendingYesNo).
 */
export function getReplyQuestion(reply: AylaReply | null | undefined, asked?: string) {
  if (!reply) return null;
  if (reply.question) return reply.question;
  const last = lastQuestionSentence(reply.text);
  if (isVaultQuestion(reply, asked)) {
    // "Wat wil je toevoegen?": answered in words. "Zal ik het toevoegen?": Ja and Nee, without asking it again.
    if (!last) return ADD_EVIDENCE_QUESTION;
    return endsWithYesNoQuestion(reply.text) ? { text: last, choices: YES_NO_CHOICES } : null;
  }
  if (!reply.accessRequest && endsWithYesNoQuestion(reply.text)) return { text: last!, choices: YES_NO_CHOICES };
  return null;
}
const YES_LABEL = /^(ja|jazeker|ja graag|graag|ja,? graag|ja,? toevoegen|toevoegen|yes)\b/i;

/**
 * Whether Ayla offers to add something to the vault (Figma 976:7971: "Wil je iets toevoegen?" with Ja and Nee). The
 * contract has navigation "addEvidence" and proposedAction "addVaultItem" for this; the Ayla function does not send
 * them yet, so a question about adding to the vault counts too.
 */
export function offersToAddEvidence(reply: AylaReply | null | undefined, asked?: string) {
  // Only once she has asked everything: with a question for words still open, the answer comes first.
  if (!reply || reply.accessRequest || stillAsks(reply.text)) return false;
  // Her last question is about something else ("Wil je iemand vragen dit diploma te bevestigen?"): a plain Ja or Nee,
  // even when the reply still carries the item she was building.
  const last = lastQuestionSentence([reply.text, reply.question?.text].filter(Boolean).join(' '))?.toLowerCase();
  if (last && !last.includes('kluis') && !ADD_WORDS.test(last)) return false;
  if (reply.navigation?.screen === 'addEvidence' || reply.proposedAction?.kind === 'addVaultItem') return true;
  if (asksToPutInVault(reply)) return true;
  if (isVaultQuestion(reply, asked)) return !lastQuestionSentence(reply.text) || endsWithYesNoQuestion(reply.text);
  if (!reply.question) return false;
  const words = `${reply.question.text} ${reply.text}`.toLowerCase();
  return words.includes('kluis') && ADD_WORDS.test(words);
}

export function isYesChoice(label: string) {
  return YES_LABEL.test(label.trim());
}

/** The skills Ayla suggested in this reply (a skillSuggestions block), if any. */
export function getSuggestedSkills(reply: AylaReply | null | undefined) {
  const names = (reply?.blocks ?? []).flatMap((block) => (block.type === 'skillSuggestions' ? block.skills.map((skill) => skill.name) : []));
  return [...new Set(names.map((name) => name.trim()).filter(Boolean))];
}

/** The file name without its extension and with dashes as spaces: a first guess at a title (as on iOS). */
export function suggestedTitle(fileName: string) {
  const base = fileName.replace(/\.[^.]+$/, '');
  return base.replace(/[-_]+/g, ' ').split(' ').filter(Boolean).join(' ').slice(0, 200);
}
