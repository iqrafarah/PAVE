// Keeping, expiring and archiving: the words and rules of iOS RetentionMessages and PaveRetention, the same in
// Instellingen, the chats and the vault.

export type ChatExpiryStart = 'last_message' | 'created';

/** How long chats stay ("Verval", as in WhatsApp). Nothing expires unless the account chose it. */
export interface ChatExpiry {
  /** After how many days a chat is deleted; null is no expiry. */
  days: number | null;
  start: ChatExpiryStart;
  keepsPinned: boolean;
  keepsLocked: boolean;
}

/** What the account chose about keeping its data (profiles.chat_expiry_* and ayla_uses_archive). */
export interface PaveRetention {
  chatExpiry: ChatExpiry;
  /** Whether Ayla may use archived evidence she was allowed to see. Off unless the account turns it on. */
  aylaUsesArchive: boolean;
}

export const DEFAULT_RETENTION: PaveRetention = {
  chatExpiry: { days: null, start: 'last_message', keepsPinned: true, keepsLocked: true },
  aylaUsesArchive: false,
};

/** The periods to choose from, in days. */
export const CHAT_EXPIRY_PERIODS = [1, 7, 30, 90] as const;

export const SETTINGS_DATA_PATH = '/instellingen/gegevens-bewaren';
export const SETTINGS_ARCHIVE_PATH = '/instellingen/gearchiveerd';

export const RETENTION_SECTION = 'Je gegevens';
export const RETENTION_TITLE = 'Gegevens bewaren';
export const RETENTION_ARCHIVE = 'Archiveren';
export const RETENTION_ARCHIVE_TITLE = 'Archief';
export const RETENTION_RESTORE = 'Terugzetten';
export const RETENTION_EXPIRY = 'Verval';
export const RETENTION_NO_EXPIRY = 'Geen verval';
export const RETENTION_FOLLOWS_SETTINGS = 'Zoals in Instellingen';
export const RETENTION_NEVER = 'Nooit';

export const RETENTION_EXPIRE_LABEL = 'Chats laten vervallen';
export const RETENTION_START_LABEL = 'De tijd loopt vanaf';
export const RETENTION_KEEP_PINNED = 'Vastgezette chats bewaren';
export const RETENTION_KEEP_LOCKED = 'Vergrendelde chats bewaren';
export const RETENTION_AYLA_ARCHIVE = 'Ayla mag je archief gebruiken';

export const RETENTION_EXPIRY_HINT =
  'Na deze tijd verdwijnt een chat vanzelf. Verwijderd is definitief: je kunt een chat daarna niet terughalen.';
export const RETENTION_NEVER_EXPIRES = 'Chats in een project en chats in je archief vervallen nooit.';
export const RETENTION_ARCHIVE_HINT =
  'Wat je archiveert verdwijnt uit beeld, maar blijft bewaard tot je het terugzet of verwijdert. Gearchiveerde bewijsstukken kun je niet delen.';
export const RETENTION_AYLA_ARCHIVE_HINT =
  'Staat dit uit, dan gebruikt Ayla niets uit je archief, ook niet als ze een bewijsstuk eerder mocht zien.';
export const RETENTION_NOT_AVAILABLE = 'Dit komt beschikbaar zodra PAVE is bijgewerkt.';
export const RETENTION_LOADING = 'Laden…';
export const RETENTION_LOAD_FAILED = 'Je keuze kon niet worden geladen. Probeer het opnieuw.';
export const RETENTION_SAVE_FAILED = 'De keuze is niet opgeslagen. Probeer het opnieuw.';
export const RETENTION_RETRY = 'Opnieuw proberen';
export const RETENTION_CONFIRM_TITLE = 'Chats verwijderen?';
export const RETENTION_CONFIRM_BUTTON = 'Ja, verwijderen';
export const RETENTION_EXPIRY_FAILED = 'Het verval aanpassen lukte niet. Probeer het opnieuw.';

export const ARCHIVE_KIND_CHATS = 'Chats';
export const ARCHIVE_KIND_EVIDENCE = 'Bewijsstukken';
export const ARCHIVE_KIND_LABEL = 'Soort';
export const ARCHIVE_SEARCH_CHATS = 'Zoek in chats';
export const ARCHIVE_SEARCH_EVIDENCE = 'Zoek in bewijsstukken';
export const ARCHIVE_SORT_LABEL = 'Sorteren';
export const ARCHIVE_SORT_NEWEST = 'Nieuwste eerst';
export const ARCHIVE_SORT_OLDEST = 'Oudste eerst';
export const ARCHIVE_SORT_NAME = 'Naam';
export const ARCHIVE_CHATS_EMPTY_TITLE = 'Je hebt geen chats in je archief';
export const ARCHIVE_CHATS_EMPTY_BODY = 'Open het menu van een chat en kies Archiveren om hem hier te bewaren.';
export const ARCHIVE_EVIDENCE_EMPTY_TITLE = 'Je hebt geen bewijsstukken in je archief';
export const ARCHIVE_EVIDENCE_EMPTY_BODY = 'Open het menu van een bewijsstuk in je kluis en kies Archiveren om het hier te bewaren.';
export const ARCHIVE_CHATS_NO_MATCH = 'Geen chats gevonden.';
export const ARCHIVE_EVIDENCE_NO_MATCH = 'Geen bewijsstukken gevonden.';
export const ARCHIVE_DELETE_CHAT_TITLE = 'Chat verwijderen?';
export const ARCHIVE_DELETE_ITEM_TITLE = 'Uit je kluis verwijderen?';
export const ARCHIVE_DELETE = 'Verwijderen';
export const ARCHIVE_FAILED = 'Dat lukte niet. Probeer het opnieuw.';

export function getRetentionPeriod(days: number | null) {
  if (days === null) return RETENTION_NO_EXPIRY;
  return days === 1 ? 'Na 1 dag' : `Na ${days} dagen`;
}

export function getRetentionStart(start: ChatExpiryStart) {
  return start === 'created' ? 'Het aanmaken van de chat' : 'Het laatste bericht';
}

/** A chat's own choice (ayla_conversations.expiry_days): null follows the account, 0 is never. */
export function getChatExpiryTitle(expiryDays: number | null) {
  if (expiryDays === null) return RETENTION_FOLLOWS_SETTINGS;
  if (expiryDays === 0) return RETENTION_NEVER;
  return getRetentionPeriod(expiryDays);
}

/** The choices in a chat's Verval menu, as stored: follow the account, never, then the periods. */
export const CHAT_EXPIRY_CHOICES: (number | null)[] = [null, 0, ...CHAT_EXPIRY_PERIODS];

/** Before a choice that can delete chats at once. */
export function getRetentionConfirmMessage(expiry: ChatExpiry) {
  const period = expiry.days === 1 ? '1 dag' : `${expiry.days} dagen`;
  const since = expiry.start === 'created' ? 'geleden zijn aangemaakt' : 'niet zijn gebruikt';
  return `Chats die langer dan ${period} ${since} worden verwijderd, ook de bestaande. Dit kan niet ongedaan worden gemaakt.`;
}

const DAY_MS = 86_400_000;

/** "Verdwijnt over 3 dagen", "Verdwijnt morgen", "Verdwijnt vandaag". */
export function getExpiresText(date: Date, now = new Date()) {
  const days = Math.ceil((date.getTime() - now.getTime()) / DAY_MS);
  if (days <= 0) return 'Verdwijnt vandaag';
  if (days === 1) return 'Verdwijnt morgen';
  return `Verdwijnt over ${days} dagen`;
}

export function getChatExpiresMessage(title: string, date: Date, now = new Date()) {
  const when = date <= now ? 'meteen' : getExpiresText(date, now).replace('Verdwijnt ', '');
  return `De chat “${title}” wordt dan ${when} voorgoed verwijderd. Dit kan niet ongedaan worden gemaakt.`;
}

export interface ExpiringChat {
  archivedAt: string | null;
  pinnedAt: string | null;
  createdAt: string | null;
  updatedAt: string;
  expiryDays: number | null;
  isLocked: boolean;
  isInProject: boolean;
}

/**
 * When this chat is deleted, or null when it stays. The same rules as ayla_delete_expired_chats in Supabase: a chat in
 * the archive or in a project never expires, and an own choice for the chat wins over the account's.
 */
export function getChatExpiresAt(expiry: ChatExpiry, chat: ExpiringChat): Date | null {
  if (chat.archivedAt || chat.isInProject) return null;
  const days = chat.expiryDays === null ? expiry.days : chat.expiryDays === 0 ? null : chat.expiryDays;
  if (!days || days <= 0) return null;
  if (chat.pinnedAt && expiry.keepsPinned) return null;
  if (chat.isLocked && expiry.keepsLocked) return null;
  const from = expiry.start === 'created' ? (chat.createdAt ?? chat.updatedAt) : chat.updatedAt;
  return new Date(new Date(from).getTime() + days * DAY_MS);
}

/**
 * A shorter time, counting from making the chat instead of its last message, or no longer keeping pinned or locked
 * chats: chats that stayed until now can go at once, so it is asked first.
 */
export function retentionDeletesMore(next: ChatExpiry, previous: ChatExpiry) {
  if (next.days === null) return false;
  if (previous.days === null || next.days < previous.days) return true;
  if (next.start === 'created' && previous.start === 'last_message') return true;
  if (!next.keepsPinned && previous.keepsPinned) return true;
  if (!next.keepsLocked && previous.keepsLocked) return true;
  return false;
}
