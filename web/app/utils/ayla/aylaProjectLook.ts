import type { VaultFolderColor, VaultFolderIcon } from '~/types/vault';

const FILLED = '/images/vault/icons';
// Projects use the filled version of each folder icon.
export const PROJECT_ICONS: Record<VaultFolderIcon, string> = {
  folder: `${FILLED}/FolderClosedSolid.svg`,
  briefcase: `${FILLED}/BriefcaseSolid.svg`,
  'academic-cap': `${FILLED}/AcademicCapSolid.svg`,
  'check-badge': `${FILLED}/CheckBadgeSolid.svg`,
  'wrench-screwdriver': `${FILLED}/WrenchScrewdriverSolid.svg`,
  'chat-bubble-left-ellipsis': `${FILLED}/ChatBubbleLeftEllipsisSolid.svg`,
  star: `${FILLED}/StarSolid.svg`,
  heart: `${FILLED}/HeartSolid.svg`,
  'code-bracket': `${FILLED}/CodeBracketSolid.svg`,
  'light-bulb': `${FILLED}/LightBulbSolid.svg`,
  'rocket-launch': `${FILLED}/RocketLaunchSolid.svg`,
  'globe-europe-africa': `${FILLED}/GlobeEuropeAfricaSolid.svg`,
  'paint-brush': `${FILLED}/PaintBrushSolid.svg`,
  'document-text': `${FILLED}/DocumentTextSolid.svg`,
  'user-group': `${FILLED}/UserGroupSolid.svg`,
  trophy: `${FILLED}/TrophySolid.svg`,
};

/** The icon and colour a project shows with: the folder in the brand colour until you pick your own. */
export function projectLook(project: { icon?: string | null; color?: string | null }) {
  const icon = (project.icon && project.icon in VAULT_FOLDER_ICONS ? project.icon : 'folder') as VaultFolderIcon;
  const hasColor = Boolean(project.color && (project.color in VAULT_FOLDER_COLORS || isFolderHex(project.color)));
  return {
    iconSrc: PROJECT_ICONS[icon],
    // null: follow the theme (text-brand), so a project you never styled looks as before.
    hex: hasColor ? folderHex(project.color as VaultFolderColor) : null,
  };
}

export const PROJECT_ICON_SEARCH_PLACEHOLDER = 'Pictogrammen zoeken';
export const PROJECT_ICON_PICKER_LABEL = 'Icoon en kleur kiezen';
export const PROJECT_ICON_NONE_FOUND = 'Geen pictogram gevonden';
