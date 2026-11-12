import type {
  VaultCategoryFolder,
  VaultCategoryFolders,
  VaultFileRole,
  VaultFilter,
  VaultFolder,
  VaultFolderColor,
  VaultFolderIcon,
  VaultItem,
  VaultItemCategory,
  VaultOrigin,
  VaultShelf,
  VaultShelfEntry,
  VaultSource,
  VaultStatus,
} from '~/types/vault';

// The rules of the vault, the same as on iOS (PAVECore/Vault and Features/Vault/VaultStyle.swift).

const ICONS = '/images/vault/icons';

export const VAULT_CATEGORIES: VaultItemCategory[] = [
  'diplomas',
  'certificates',
  'badges',
  'projects',
  'workExperience',
  'internships',
  'skills',
  'feedback',
  'reflections',
  'other',
];

/** The folders that are always on top of the vault, as in the design. Other categories appear once they hold something. */
export const FEATURED_CATEGORIES: VaultItemCategory[] = ['certificates', 'diplomas', 'feedback', 'projects'];

export const VAULT_CATEGORY_PLURALS: Record<VaultItemCategory, string> = {
  diplomas: "Diploma's",
  certificates: 'Certificaten',
  badges: 'Badges',
  projects: 'Projecten',
  workExperience: 'Werkervaring',
  internships: 'Stages',
  skills: 'Vaardigheden',
  feedback: 'Feedback',
  reflections: 'Reflecties',
  other: 'Overige',
};

/** The outline icon on the folder tiles, as in the design. */
export const CATEGORY_FOLDER_ICONS: Record<VaultItemCategory, string> = {
  diplomas: `${ICONS}/AcademicCapOutline.svg`,
  certificates: `${ICONS}/CheckBadgeOutline.svg`,
  badges: `${ICONS}/StarOutline.svg`,
  projects: `${ICONS}/WrenchScrewdriverOutline.svg`,
  workExperience: `${ICONS}/BriefcaseOutline.svg`,
  internships: `${ICONS}/BuildingOfficeOutline.svg`,
  skills: `${ICONS}/PaintBrushOutline.svg`,
  feedback: `${ICONS}/ChatBubbleLeftEllipsisOutline.svg`,
  reflections: `${ICONS}/DocumentTextOutline.svg`,
  other: `${ICONS}/FolderOutline.svg`,
};

/** The coloured band on top of a card (iOS VaultCategory.tint). */
export const CATEGORY_TINTS: Record<VaultItemCategory, string> = {
  diplomas: 'bg-card-tint-apricot',
  certificates: 'bg-card-tint-apricot',
  badges: 'bg-card-tint-apricot',
  workExperience: 'bg-card-tint-green',
  internships: 'bg-card-tint-green',
  projects: 'bg-card-tint-lime',
  skills: 'bg-card-tint-lime',
  feedback: 'bg-card-tint-lavender',
  reflections: 'bg-card-tint-lavender',
  other: 'bg-card-tint-lavender',
};

export const VAULT_STATUSES: VaultStatus[] = ['verified', 'toVerify', 'rejected'];

export const VAULT_STATUS_STYLES: Record<VaultStatus, { icon: string; className: string }> = {
  verified: { icon: '/images/vault/status-verified.svg', className: 'bg-status-verified-surface text-brand' },
  toVerify: { icon: `${ICONS}/ClockSolid.svg`, className: 'bg-status-pending-surface text-status-pending' },
  rejected: { icon: '/images/vault/status-rejected.svg', className: 'bg-status-rejected-surface text-status-rejected' },
};

export const VAULT_ORIGINS: VaultOrigin[] = ['own', 'organisation', 'ayla'];

export const VAULT_FOLDER_COLORS: Record<VaultFolderColor, string> = {
  green: '#355d4c',
  blue: '#2f5b7c',
  purple: '#5b4b8a',
  rust: '#9a4a26',
  rose: '#943a58',
  slate: '#4a5250',
};

export const VAULT_FOLDER_ICONS: Record<VaultFolderIcon, string> = {
  folder: `${ICONS}/FolderOutline.svg`,
  briefcase: `${ICONS}/BriefcaseOutline.svg`,
  'academic-cap': `${ICONS}/AcademicCapOutline.svg`,
  'check-badge': `${ICONS}/CheckBadgeOutline.svg`,
  'wrench-screwdriver': `${ICONS}/WrenchScrewdriverOutline.svg`,
  'chat-bubble-left-ellipsis': `${ICONS}/ChatBubbleLeftEllipsisOutline.svg`,
  star: `${ICONS}/StarOutline.svg`,
  heart: `${ICONS}/HeartOutline.svg`,
  'code-bracket': `${ICONS}/CodeBracketOutline.svg`,
  'light-bulb': `${ICONS}/LightBulbOutline.svg`,
  'rocket-launch': `${ICONS}/RocketLaunchOutline.svg`,
  'globe-europe-africa': `${ICONS}/GlobeEuropeAfricaOutline.svg`,
  'paint-brush': `${ICONS}/PaintBrushOutline.svg`,
  'document-text': `${ICONS}/DocumentTextOutline.svg`,
  'user-group': `${ICONS}/UserGroupOutline.svg`,
  trophy: `${ICONS}/TrophyOutline.svg`,
};

/** The light band behind a folder: 11% of its colour on white, which for green is the tint of the design. */
export function folderSurface(color: VaultFolderColor) {
  return color === 'green' ? 'var(--color-tint)' : `color-mix(in srgb, ${VAULT_FOLDER_COLORS[color]} 11%, white)`;
}

export function folderStyle(folder: VaultFolder) {
  const color = folder.color ?? 'green';
  return { color, icon: folder.icon ?? 'folder', hex: VAULT_FOLDER_COLORS[color], surface: folderSurface(color) };
}

const MONTHS = ['jan', 'feb', 'mrt', 'apr', 'mei', 'jun', 'jul', 'aug', 'sep', 'okt', 'nov', 'dec'];

/** "mrt 2025", the way dates are written on vault cards. */
export function monthAndYear(day: string) {
  const [year, month] = day.split('-').map(Number);
  return `${MONTHS[(month ?? 1) - 1]} ${year}`;
}

/** "3 mrt 2025". */
export function fullDay(day: string) {
  return `${Number(day.slice(8, 10))} ${monthAndYear(day)}`;
}

/** "mrt 2025 - dec 2025", "nov 2025 - nu" or "jun 2025". */
export function itemPeriod(item: VaultItem) {
  const { startDate: start, issuedOn } = item;
  const end = item.isCurrent ? null : item.endDate;
  if (issuedOn && !start && !item.endDate) return monthAndYear(issuedOn);
  if (start && item.isCurrent) return `${monthAndYear(start)} - nu`;
  if (start && end) {
    const [from, to] = [monthAndYear(start), monthAndYear(end)];
    return from === to ? from : `${from} - ${to}`;
  }
  if (start) return `vanaf ${monthAndYear(start)}`;
  if (end) return `tot ${monthAndYear(end)}`;
  return issuedOn ? monthAndYear(issuedOn) : null;
}

/** "Pixelwerk, Eindhoven". */
export function itemPlace(item: VaultItem) {
  const parts = [item.organisationName, item.organisationLocation].map((part) => part?.trim()).filter(Boolean);
  return parts.length ? parts.join(', ') : null;
}

/** A confirmed item stays as it was confirmed, and what an organisation added is theirs. The rest you can change. */
export function isEditable(item: VaultItem) {
  return item.source === 'user' && item.status !== 'verified';
}

export function itemCount(count: number) {
  return count === 1 ? '1 item' : `${count} items`;
}

function today() {
  return new Date().toISOString().slice(0, 10);
}

/** The day the vault sorts on: when you got it, when it ended, today while it still goes on, or when it started. */
function sortDay(item: VaultItem) {
  return item.issuedOn ?? (item.isCurrent ? today() : (item.endDate ?? item.startDate)) ?? item.createdAt.slice(0, 10);
}

function matchesOrigin(origin: VaultOrigin, source: VaultSource) {
  if (origin === 'own') return source === 'user';
  if (origin === 'organisation') return source === 'organization' || source === 'import';
  return source === 'ayla';
}

/** Lower case and without accents, so "diploma" finds "Diploma's" and "verifieren" finds "Verifiëren". */
function plain(text: string) {
  return text.normalize('NFD').replace(/[̀-ͯ]/g, '').toLowerCase();
}

function searchableText(item: VaultItem) {
  return plain(
    [item.title, VAULT_CATEGORY_PLURALS[item.category], item.organisationName, item.organisationLocation, item.description, ...item.skills]
      .filter(Boolean)
      .join(' '),
  );
}

export function isOnShelf(item: VaultItem, shelf: VaultShelf) {
  if (shelf.kind === 'category') {
    return item.category === shelf.category || (Boolean(shelf.folderId) && item.folderId === shelf.folderId);
  }
  if (shelf.kind === 'folder') return item.folderId === shelf.id;
  return true;
}

export function isSameShelf(a: VaultShelf, b: VaultShelf) {
  if (a.kind === 'category' && b.kind === 'category') return a.category === b.category;
  if (a.kind === 'folder' && b.kind === 'folder') return a.id === b.id;
  return a.kind === b.kind;
}

export function createFilter(): VaultFilter {
  return { shelf: { kind: 'all' }, status: null, origin: null, order: 'newest', searchText: '' };
}

/** Status or Bron is set. The shelf, the order and search do not count: "Alle" clears just these. */
export function narrowsDown(filter: VaultFilter) {
  return filter.status !== null || filter.origin !== null;
}

export function applyFilter(items: VaultItem[], filter: VaultFilter) {
  const query = plain(filter.searchText.trim());
  return items
    .filter((item) => {
      if (!isOnShelf(item, filter.shelf)) return false;
      if (filter.status && item.status !== filter.status) return false;
      if (filter.origin && !matchesOrigin(filter.origin, item.source)) return false;
      return !query || searchableText(item).includes(query);
    })
    .sort((left, right) => {
      const [a, b] = [sortDay(left), sortDay(right)];
      if (a === b) return right.updatedAt.localeCompare(left.updatedAt);
      return filter.order === 'newest' ? b.localeCompare(a) : a.localeCompare(b);
    });
}

/** The start of a logo's or cover's file name in Storage ("uid/item/cover-uuid.jpg"); evidence has no prefix. */
export const VAULT_FILE_PREFIXES = { logo: 'logo-', cover: 'cover-' } as const;

export function fileRole(path: string): VaultFileRole {
  const name = path.split('/').pop() ?? '';
  if (name.startsWith(VAULT_FILE_PREFIXES.logo)) return 'logo';
  if (name.startsWith(VAULT_FILE_PREFIXES.cover)) return 'cover';
  return 'evidence';
}

/** The pictures a browser can show; HEIC only works in Safari. */
export const SHOWN_IMAGE_TYPES = ['image/jpeg', 'image/png'];

/** The folder icon a category starts with, as one of the choices in the folder editor. */
function categoryIconKey(category: VaultItemCategory): VaultFolderIcon {
  const src = CATEGORY_FOLDER_ICONS[category];
  const match = (Object.entries(VAULT_FOLDER_ICONS) as [VaultFolderIcon, string][]).find(([, path]) => path === src);
  return match?.[0] ?? 'folder';
}

/**
 * The folders above the vault: the standard ones you did not remove (the four from the design always, the other
 * categories once they hold something), then the folders you made.
 */
export function buildShelves(
  items: VaultItem[],
  folders: VaultFolder[],
  categoryFolders: VaultCategoryFolders,
): VaultShelfEntry[] {
  const count = (shelf: VaultShelf) => items.filter((item) => isOnShelf(item, shelf)).length;
  const plain = (name: string) => name.trim().toLocaleLowerCase('nl');
  // A folder you made with the name of a standard folder is shown as that folder, not twice.
  const twinOf = (title: string) => folders.find((folder) => plain(folder.name) === plain(title));
  const twins = new Set<string>();
  const standard = VAULT_CATEGORIES.filter((category) => {
    if (categoryFolders[category]?.isHidden) return false;
    return FEATURED_CATEGORIES.includes(category) || count({ kind: 'category', category }) > 0;
  })
    .sort((a, b) => {
      const [left, right] = [FEATURED_CATEGORIES.indexOf(a), FEATURED_CATEGORIES.indexOf(b)];
      return (left < 0 ? 99 : left) - (right < 0 ? 99 : right);
    })
    .map((category): VaultShelfEntry => {
      const custom = categoryFolders[category] ?? {};
      const colorKey = custom.color ?? 'green';
      const iconKey = custom.icon ?? categoryIconKey(category);
      const title = custom.name ?? VAULT_CATEGORY_PLURALS[category];
      const twin = twinOf(title) ?? twinOf(VAULT_CATEGORY_PLURALS[category]);
      if (twin) twins.add(twin.id);
      const shelf = { kind: 'category' as const, category, ...(twin ? { folderId: twin.id } : {}) };
      return {
        key: `category-${category}`,
        shelf,
        title,
        iconSrc: custom.icon ? VAULT_FOLDER_ICONS[custom.icon] : CATEGORY_FOLDER_ICONS[category],
        hex: VAULT_FOLDER_COLORS[colorKey],
        surface: folderSurface(colorKey),
        colorKey,
        iconKey,
        count: count(shelf),
        isStandard: true,
      };
    });
  const own = folders.filter((folder) => !twins.has(folder.id)).map((folder): VaultShelfEntry => {
    const style = folderStyle(folder);
    const shelf = { kind: 'folder' as const, id: folder.id };
    return {
      key: `folder-${folder.id}`,
      shelf,
      title: folder.name,
      iconSrc: VAULT_FOLDER_ICONS[style.icon],
      hex: style.hex,
      surface: style.surface,
      colorKey: style.color,
      iconKey: style.icon,
      count: count(shelf),
      isStandard: false,
    };
  });
  return [...standard, ...own];
}

/** Keeps only what this version understands from user_metadata.vault_category_folders. */
export function readCategoryFolders(value: unknown): VaultCategoryFolders {
  if (!value || typeof value !== 'object') return {};
  const result: VaultCategoryFolders = {};
  for (const [category, raw] of Object.entries(value as Record<string, unknown>)) {
    if (!(VAULT_CATEGORIES as string[]).includes(category) || !raw || typeof raw !== 'object') continue;
    const entry = raw as Record<string, unknown>;
    const folder: VaultCategoryFolder = {};
    if (typeof entry.name === 'string' && entry.name.trim()) folder.name = entry.name.trim().slice(0, 100);
    if (typeof entry.color === 'string' && entry.color in VAULT_FOLDER_COLORS) folder.color = entry.color as VaultFolderColor;
    if (typeof entry.icon === 'string' && entry.icon in VAULT_FOLDER_ICONS) folder.icon = entry.icon as VaultFolderIcon;
    if (entry.isHidden === true) folder.isHidden = true;
    result[category as VaultItemCategory] = folder;
  }
  return result;
}
