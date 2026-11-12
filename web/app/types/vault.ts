import type { VaultCategory } from '~/types/ayla';

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
}

export type VaultCoverChoice = 'none' | 'cover';

export interface VaultSkillOption {
  name: string;
  isSelected: boolean;
}

/** Only trusted server code can confirm or reject an item; the app never sets this. */
export type VaultStatus = 'toVerify' | 'verified' | 'rejected';

/** Who put the item in the vault. */
export type VaultSource = 'user' | 'organization' | 'ayla' | 'import';

/** What a file is for: the card's logo, its cover ("Omslag") or evidence. Told apart by the start of its name. */
export type VaultFileRole = 'logo' | 'cover' | 'evidence';

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
  folderId: string | null;
  category: VaultItemCategory;
  title: string;
  description: string | null;
  organisationName: string | null;
  organisationLocation: string | null;
  startDate: string | null;
  endDate: string | null;
  issuedOn: string | null;
  isCurrent: boolean;
  status: VaultStatus;
  source: VaultSource;
  // The logo on the card: the one of the organisation the item is linked to (organizations.logo_url), else the one you
  // added yourself. Without either the card shows the first letter.
  logoUrl: string | null;
  // A short-lived link to the cover picture ("Omslag"), shown at the top of the card.
  coverUrl: string | null;
  // The skills the user kept; Ayla's proposals that were not accepted are left out.
  skills: string[];
  files: VaultFile[];
  createdAt: string;
  updatedAt: string;
}

export type VaultFolderColor = 'green' | 'blue' | 'purple' | 'rust' | 'rose' | 'slate';

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

/** A folder the user made. An item can sit in one folder and keeps its category. */
export interface VaultFolder {
  id: string;
  name: string;
  color: VaultFolderColor | null;
  icon: VaultFolderIcon | null;
  createdAt: string;
}

/**
 * What you changed about a standard folder (a category): its name, colour or icon, or that you removed it from the
 * row. Kept in the account (user_metadata.vault_category_folders), so it is the same on every device.
 */
export interface VaultCategoryFolder {
  name?: string;
  color?: VaultFolderColor;
  icon?: VaultFolderIcon;
  isHidden?: boolean;
}

export type VaultCategoryFolders = Partial<Record<VaultItemCategory, VaultCategoryFolder>>;

/** One folder in the row above the vault, a standard one or one you made, ready to show. */
export interface VaultShelfEntry {
  key: string;
  shelf: Exclude<VaultShelf, { kind: 'all' }>;
  title: string;
  // The icon and colours to draw it with.
  iconSrc: string;
  hex: string;
  surface: string;
  // The choices it starts with when you change it.
  colorKey: VaultFolderColor;
  iconKey: VaultFolderIcon;
  count: number;
  isStandard: boolean;
}

/** Which part of the vault you look at: everything, one category or one of your own folders. */
export type VaultShelf =
  | { kind: 'all' }
  // folderId: a folder you made with the same name ("Certificaten" from before the standard folders), shown as one.
  | { kind: 'category'; category: VaultItemCategory; folderId?: string }
  | { kind: 'folder'; id: string };

/** "Zelf toegevoegd", "Van een organisatie" (also imports) or "Via Ayla". */
export type VaultOrigin = 'own' | 'organisation' | 'ayla';

export type VaultOrder = 'newest' | 'oldest';

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
