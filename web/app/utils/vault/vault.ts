import { PERSONAL_THEMES } from '~/utils/settings/settingsMessages';
import type {
  VaultFileRole,
  VaultFilter,
  VaultFolder,
  VaultFolderColor,
  VaultFolderColorChoice,
  VaultFolderHex,
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

function themeHex(id: (typeof PERSONAL_THEMES)[number]['id']) {
  return PERSONAL_THEMES.find((theme) => theme.id === id)!.hex.toLowerCase() as VaultFolderHex;
}

// The same colours as the themes in Instellingen, in the same order. The names are those the database knows.
export const VAULT_FOLDER_COLORS: Record<VaultFolderColor, VaultFolderHex> = {
  green: themeHex('green'),
  blue: themeHex('blue'),
  gold: themeHex('gold'),
  rose: themeHex('pink'),
  rust: themeHex('orange'),
  purple: themeHex('purple'),
  red: themeHex('red'),
  lime: themeHex('lime'),
  slate: '#4a5250',
};

/** The colours to choose from: the themes. Slate is only kept for folders that already have it. */
export const VAULT_FOLDER_PICKER_COLORS: VaultFolderColor[] = ['green', 'blue', 'gold', 'rose', 'rust', 'purple', 'red', 'lime'];

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

export function isFolderHex(color: string): color is VaultFolderHex {
  return /^#[0-9a-f]{6}$/.test(color);
}

// The theme colours of Settings that have another name in the folder colours.
const THEME_FOLDER_COLORS: Record<string, VaultFolderColor> = { pink: 'rose', orange: 'rust' };

/** The colour a folder gets when you pick none: the theme colour of Settings (or your own colour when you chose one). */
export function folderColorForTheme(theme: string, customColor: string | null): VaultFolderColorChoice {
  if (theme === 'custom' && customColor && /^#[0-9a-f]{6}$/i.test(customColor)) return customColor.toLowerCase() as VaultFolderHex;
  const named = THEME_FOLDER_COLORS[theme] ?? theme;
  return (VAULT_FOLDER_PICKER_COLORS as string[]).includes(named) ? (named as VaultFolderColor) : 'green';
}

/** The colour itself: a named colour from the list, or the one you picked. */
export function folderHex(color: VaultFolderColorChoice) {
  return isFolderHex(color) ? color : VAULT_FOLDER_COLORS[color];
}

/** The light band behind a folder: 11% of its colour on white. */
export function folderSurface(color: VaultFolderColorChoice) {
  return `color-mix(in srgb, ${folderHex(color)} 11%, white)`;
}

/** The icon on a folder is always white. */
export function folderIconColor(_color: VaultFolderColorChoice) {
  return 'white';
}

export function folderStyle(folder: VaultFolder, fallback: VaultFolderColorChoice = 'green') {
  const color: VaultFolderColorChoice = folder.color ?? fallback;
  return {
    color,
    icon: folder.icon ?? 'folder',
    hex: folderHex(color),
    surface: folderSurface(color),
    iconColor: folderIconColor(color),
  };
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

/**
 * Every item can be changed (migration 20261112120000). A confirmed one then goes back to "Niet bevestigd" until it is
 * confirmed again, so the app says so first (iOS changeNeedsReconfirmation).
 */
export function needsReconfirmation(item: VaultItem) {
  return item.status === 'verified';
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
  return shelf.kind === 'all' || item.folderIds.includes(shelf.id);
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
      // "Eigen volgorde": what you dragged keeps its place; what you never moved comes after it.
      if (filter.order === 'custom' && left.position !== right.position) {
        return (left.position ?? Number.MAX_SAFE_INTEGER) - (right.position ?? Number.MAX_SAFE_INTEGER);
      }
      const [a, b] = [sortDay(left), sortDay(right)];
      if (a === b) return right.updatedAt.localeCompare(left.updatedAt);
      return filter.order === 'oldest' ? a.localeCompare(b) : b.localeCompare(a);
    });
}

/**
 * Before migration 20261112120000 there was no role column and the web marked a logo or cover by the start of its file
 * name ("uid/item/cover-uuid.jpg"). Those files are still recognised; new ones also get the prefix, harmless after it.
 */
export const VAULT_FILE_PREFIXES = { logo: 'logo-', cover: 'cover-' } as const;

export function fileRole(role: string | null | undefined, path: string): VaultFileRole {
  if (role === 'logo' || role === 'cover') return role;
  const name = path.split('/').pop() ?? '';
  if (name.startsWith(VAULT_FILE_PREFIXES.logo)) return 'logo';
  if (name.startsWith(VAULT_FILE_PREFIXES.cover)) return 'cover';
  return 'document';
}

/** The pictures a browser can show; HEIC only works in Safari. */
export const SHOWN_IMAGE_TYPES = ['image/jpeg', 'image/png'];

/** Enough for a report, a certificate and a few photos, without turning the vault into file storage (as on iOS). */
export const MAX_DOCUMENTS = 5;

/** The four folders every account starts with (iOS VaultExampleFolders, migration 20261112120000). */
export const EXAMPLE_FOLDERS: { name: string; category: VaultItemCategory; color: VaultFolderColor; icon: VaultFolderIcon }[] = [
  { name: 'Certificaten', category: 'certificates', color: 'green', icon: 'check-badge' },
  { name: "Diploma's", category: 'diplomas', color: 'green', icon: 'academic-cap' },
  { name: 'Feedback', category: 'feedback', color: 'green', icon: 'chat-bubble-left-ellipsis' },
  { name: 'Projecten', category: 'projects', color: 'green', icon: 'wrench-screwdriver' },
];

/** The icon of the folder that is made for a kind of evidence, such as Stages when you add a stage. */
export const CATEGORY_FOLDER_ICON_KEYS: Record<VaultItemCategory, VaultFolderIcon> = {
  diplomas: 'academic-cap',
  certificates: 'check-badge',
  badges: 'star',
  projects: 'wrench-screwdriver',
  workExperience: 'briefcase',
  internships: 'briefcase',
  skills: 'paint-brush',
  feedback: 'chat-bubble-left-ellipsis',
  reflections: 'document-text',
  other: 'folder',
};

/**
 * The folder of a kind of evidence, where a new item goes: the example folder (Projecten for a project), or a folder
 * you named after the kind yourself (Stages, Werkervaring). Null when you have neither.
 */
export function kindFolder(category: VaultItemCategory, folders: VaultFolder[]) {
  const names = [EXAMPLE_FOLDERS.find((example) => example.category === category)?.name, VAULT_CATEGORY_PLURALS[category]]
    .filter((name): name is string => Boolean(name))
    .map((name) => name.toLocaleLowerCase('nl'));
  return folders.find((folder) => names.includes(folder.name.trim().toLocaleLowerCase('nl'))) ?? null;
}

/** The folders above the vault, in the order they were made, each with its look and how many items it holds. */
export function buildShelves(items: VaultItem[], folders: VaultFolder[], fallback: VaultFolderColorChoice = 'green'): VaultShelfEntry[] {
  return folders.map((folder) => {
    const style = folderStyle(folder, fallback);
    return {
      folder,
      iconSrc: VAULT_FOLDER_ICONS[style.icon],
      hex: style.hex,
      surface: style.surface,
      iconColor: style.iconColor,
      colorKey: style.color,
      iconKey: style.icon,
      count: items.filter((item) => item.folderIds.includes(folder.id)).length,
    };
  });
}

/** "In de map Projecten" or "In de mappen Projecten, Stage". */
export function inFolders(names: string[]) {
  return names.length === 1 ? `In de map ${names[0]}` : `In de mappen ${names.join(', ')}`;
}
