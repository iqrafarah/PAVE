import type { VaultCategory } from '~/types/ayla';
import type { VaultValidationRequest } from '~/types/verification';

/** The categories of vault_items, as in the database. "other" (Overige) came with the second vault migration. */
export type VaultItemCategory = VaultCategory | 'other';

export type VaultAddStep = 'basis' | 'details' | 'cover' | 'skills' | 'done';

/** A month as `YYYY-MM`, the value of an `<input type="month">`. Empty when not filled in. */
export type VaultMonth = string;

export interface VaultItemDraft {
  title: string;
  category: VaultItemCategory | '';
  organisationName: string;
  startMonth: VaultMonth;
  endMonth: VaultMonth;
  issuedMonth: VaultMonth;
  description: string;
  // A period (start and end) or one date. Null follows the kind: a period for experience, one date for a diploma,
  // certificate or badge. You can choose the other way for any kind (iOS VaultItemDraft.usesPeriod).
  usesPeriod: boolean | null;
}

export interface VaultSkillOption {
  name: string;
  isSelected: boolean;
}

/** Only trusted server code can confirm or reject an item; the app never sets this. */
export type VaultStatus = 'toVerify' | 'verified' | 'rejected';

/** Who put the item in the vault. */
export type VaultSource = 'user' | 'organization' | 'ayla' | 'import';

/**
 * What a file is for (vault_item_files.role, migration 20261112120000): the evidence itself, the image in the round
 * avatar on the card (logo) or the image in the band above it (cover). At most one logo and one cover per item.
 */
export type VaultFileRole = 'document' | 'logo' | 'cover';

export interface VaultFile {
  id: string;
  name: string;
  mimeType: string;
  storagePath: string;
  role: VaultFileRole;
}

/** One piece of evidence in the vault (iOS VaultItem). Dates are `YYYY-MM-DD` without a time. */
export interface VaultItem {
  id: string;
  // Every folder the item is in (vault_item_folders), the first being vault_items.folder_id.
  folderIds: string[];
  category: VaultItemCategory;
  title: string;
  description: string | null;
  // The organisation in the directory the evidence belongs to (vault_items.organization_id), when known.
  organizationId: string | null;
  organisationName: string | null;
  organisationLocation: string | null;
  startDate: string | null;
  endDate: string | null;
  issuedOn: string | null;
  isCurrent: boolean;
  status: VaultStatus;
  source: VaultSource;
  // The round image on the card: the organisation's logo (organizations.logo_url), else your own logo, else the cover
  // (as on iOS). Without any of them the card shows the first letter.
  logoUrl: string | null;
  // A short-lived link to the cover ("Omslag"), shown in the band of a grid card.
  coverUrl: string | null;
  // "Ayla mag dit bekijken en gebruiken" is on since then; null when it is off.
  aylaAllowedAt: string | null;
  // Archived (vault_items.archived_at): out of the vault, kept until it is put back or deleted.
  archivedAt: string | null;
  // The skills the user kept; Ayla's proposals that were not accepted are left out.
  skills: string[];
  files: VaultFile[];
  createdAt: string;
  updatedAt: string;
  // Its place in "Eigen volgorde", once you dragged your evidence into an order of your own (vault_items.position).
  position: number | null;
  // The newest request to confirm it: "In afwachting" while it is open, the reason after a rejection. Null without one.
  lastRequest: VaultValidationRequest | null;
}

// The theme colours of Settings (green, blue, gold, rose = Roze, rust = Oranje, purple, red, lime), plus slate, which
// older folders may still have.
export type VaultFolderColor = 'green' | 'blue' | 'gold' | 'rose' | 'rust' | 'purple' | 'red' | 'lime' | 'slate';

/** A colour you picked yourself, as `#rrggbb` in lower case (migration 20261119120000). */
export type VaultFolderHex = `#${string}`;

/** One of the named colours, or one of your own. */
export type VaultFolderColorChoice = VaultFolderColor | VaultFolderHex;

export type VaultFolderIcon =
  | 'folder'
  | 'briefcase'
  | 'academic-cap'
  | 'check-badge'
  | 'wrench-screwdriver'
  | 'chat-bubble-left-ellipsis'
  | 'star'
  | 'heart'
  | 'code-bracket'
  | 'light-bulb'
  | 'rocket-launch'
  | 'globe-europe-africa'
  | 'paint-brush'
  | 'document-text'
  | 'user-group'
  | 'trophy';

/**
 * A folder. Every account starts with four example folders (Certificaten, Diploma's, Feedback, Projecten) that are
 * ordinary folders too. An item can be in several folders and keeps its category.
 */
export interface VaultFolder {
  id: string;
  name: string;
  color: VaultFolderColorChoice | null;
  icon: VaultFolderIcon | null;
  createdAt: string;
  // Its place in the folder row once you dragged the folders into an order of your own (vault_folders.position).
  position: number | null;
  // Pinned folders come first in the folder row (vault_folders.pinned_at); null when it is not pinned.
  pinnedAt: string | null;
}

/** One folder in the row above the vault, ready to show. */
export interface VaultShelfEntry {
  folder: VaultFolder;
  iconSrc: string;
  hex: string;
  surface: string;
  // White, or dark on a light colour of your own, so the icon on the folder stays readable.
  iconColor: string;
  colorKey: VaultFolderColorChoice;
  iconKey: VaultFolderIcon;
  count: number;
}

/** Which part of the vault you look at: everything or one folder. */
export type VaultShelf = { kind: 'all' } | { kind: 'folder'; id: string };

/** A skill Ayla proposes for evidence you are adding (Edge Function ayla-skills), with why. */
export interface VaultSkillSuggestion {
  name: string;
  reason: string;
}

/** "Zelf toegevoegd", "Van een organisatie" (also imports) or "Via Ayla". */
export type VaultOrigin = 'own' | 'organisation' | 'ayla';

// 'custom' is the order you dragged your evidence into; what you never moved comes after it, newest first.
export type VaultOrder = 'newest' | 'oldest' | 'custom';

/** Status, Bron and Datum in the design, plus search (iOS VaultFilter). */
export interface VaultFilter {
  shelf: VaultShelf;
  status: VaultStatus | null;
  origin: VaultOrigin | null;
  order: VaultOrder;
  searchText: string;
}

export interface VaultMenuOption {
  id: string;
  label: string;
  // Set for a choice (Status, Bron, Datum); left out for an action (Item toevoegen, Map aanmaken).
  isChecked?: boolean;
  icon?: string;
}

/** A part of a document's image, as fractions of its size from the top left corner (such as the logo on a certificate). */
export interface VaultEvidenceBox {
  x: number;
  y: number;
  width: number;
  height: number;
}

/** One document as "Laat Ayla invullen" sends it: the text that was read and/or a small photo (base64 JPEG). */
export interface VaultEvidenceDocument {
  name: string;
  text?: string;
  image?: string;
}

export type VaultEvidenceSourceField = 'title' | 'organisation' | 'period' | 'description';

/** What Ayla proposes after reading the documents (Edge Function ayla-evidence). Dates are `YYYY-MM-DD`. */
export interface VaultEvidenceProposal {
  category: VaultItemCategory;
  title: string;
  organisationName: string | null;
  organisationLocation: string | null;
  startDate: string | null;
  endDate: string | null;
  issuedOn: string | null;
  isCurrent: boolean;
  description: string | null;
  skills: VaultSkillSuggestion[];
  folder: string | null;
  // The documents that belong to this item, counted from 0 in the order they were sent.
  documents: number[];
  coverDocument: number | null;
  coverBox: VaultEvidenceBox | null;
  logoDocument: number | null;
  logoBox: VaultEvidenceBox | null;
  website: string | null;
  // Where each field was found, such as "pagina 1".
  sources: Partial<Record<VaultEvidenceSourceField, string>>;
  // The logo from the organisation's website, when the documents have none.
  logo: { data: string; mimeType: string; source: string } | null;
}
