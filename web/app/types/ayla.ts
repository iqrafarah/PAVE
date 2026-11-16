// The Ayla contract, matching shared/ayla/reply.schema.json. Block types the web does not know yet are skipped
// when a reply is read (see utils/aylaReply.ts), so the server can add cards without breaking the web.

export type AylaDevice = 'watch' | 'phone' | 'web';
export type AylaInput = 'voice' | 'text';

export type VaultCategory =
  | 'diplomas'
  | 'certificates'
  | 'badges'
  | 'projects'
  | 'workExperience'
  | 'internships'
  | 'skills'
  | 'feedback'
  | 'reflections';

export type AylaScreen =
  | 'home'
  | 'chat'
  | 'vault'
  | 'vaultItem'
  | 'addEvidence'
  | 'plans'
  | 'vacancies'
  | 'profile'
  | 'settings';

export type MemoryCategory =
  | 'education'
  | 'work'
  | 'goals'
  | 'skills'
  | 'values'
  | 'workStyle'
  | 'interests'
  | 'personal';

export interface AylaAttachment {
  name: string;
  text: string;
}

export interface AylaRequest {
  conversationId?: string;
  text: string;
  device: AylaDevice;
  input: AylaInput;
  context?: { screen: AylaScreen; itemId?: string };
  attachments?: AylaAttachment[];
}

export interface AylaChoice {
  id: string;
  label: string;
}

export interface RequirementLink {
  skill: string;
  requirement: string;
}

export interface VacancySalary {
  min: number;
  max: number;
  period: 'month' | 'year';
  currency: 'EUR';
  isEstimate: boolean;
}

export interface Vacancy {
  id: string;
  title: string;
  company: string;
  city?: string;
  employment?: 'fullTime' | 'partTime';
  salary?: VacancySalary;
  logoUrl?: string;
  url?: string;
  source: 'example' | 'adzuna';
  matches: RequirementLink[];
  skillGap: RequirementLink[];
}

export interface VaultSelectionBlock {
  type: 'vaultSelection';
  categories: { category: VaultCategory; count: number }[];
}

export interface VacanciesBlock {
  type: 'vacancies';
  items: Vacancy[];
}

export interface SkillSuggestionsBlock {
  type: 'skillSuggestions';
  itemId: string;
  skills: { name: string; reason: string }[];
}

export interface CvBlock {
  type: 'cv';
  profile: string;
  experience: { title: string; organisation: string; period: string; description?: string }[];
  skills: string[];
}

export type AylaBlock = VaultSelectionBlock | VacanciesBlock | SkillSuggestionsBlock | CvBlock;

export interface MemorySuggestion {
  text: string;
  category: MemoryCategory;
  replaces?: string;
}

export interface UsedMemory {
  text: string;
  category: MemoryCategory;
}

export interface AylaReply {
  version: 1;
  id: string;
  conversationId: string;
  text: string;
  question?: { text: string; choices: AylaChoice[] };
  accessRequest?: { id: string; purpose: string; categories: VaultCategory[] };
  proposedAction?: {
    id: string;
    kind: 'addVaultItem' | 'updatePlan' | 'draftProfile' | 'requestValidation';
    summary: string;
    expiresAt: string;
  };
  blocks: AylaBlock[];
  navigation?: { screen: AylaScreen; itemId?: string };
  memories?: MemorySuggestion[];
  usedMemories?: UsedMemory[];
  usedData: VaultCategory[];
}

export type AylaRole = 'user' | 'ayla';

/** A message as the chat shows it. `attachmentNames` only lives on this device: files are never stored. */
export interface ChatMessage {
  id: string;
  role: AylaRole;
  text: string;
  reply: AylaReply | null;
  createdAt: string;
  isWriting: boolean;
  attachmentNames: string[];
}

export interface Conversation {
  id: string;
  title: string;
  updatedAt: string;
  pinnedAt: string | null;
  startedOn: AylaDevice;
}

export interface MemoryNote {
  id: string;
  text: string;
  category: MemoryCategory;
  source: 'ayla' | 'user';
  conversationId: string | null;
  createdAt: string;
  updatedAt: string;
}

/** The errors from the table in docs/ayla.md, plus the ones the browser itself runs into. */
export type AylaErrorCode =
  | 'invalid_request'
  | 'not_signed_in'
  | 'insufficient_aal'
  | 'conversation_not_found'
  | 'unavailable'
  | 'offline';

/** One choice in the small "Meer opties" menu of a chat or a note. */
export interface RowMenuItem {
  id: string;
  label: string;
  isDanger?: boolean;
}
