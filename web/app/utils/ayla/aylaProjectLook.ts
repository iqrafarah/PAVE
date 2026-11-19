import type { VaultFolderColor, VaultFolderIcon } from '~/types/vault';

// Every folder icon is filled, so projects use the same set as the vault folders.
export const PROJECT_ICONS: Record<VaultFolderIcon, string> = VAULT_FOLDER_ICONS;

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

/** The default folder opens while its project is expanded; a project with its own icon keeps that icon. */
export function projectIconSrc(project: { icon?: string | null; color?: string | null }, open: boolean) {
  const look = projectLook(project);
  return open && look.iconSrc === PROJECT_ICONS.folder ? '/images/vault/icons/FolderSolid.svg' : look.iconSrc;
}

export const PROJECT_ICON_SEARCH_PLACEHOLDER = 'Pictogrammen zoeken';
export const PROJECT_ICON_PICKER_LABEL = 'Icoon en kleur kiezen';
export const PROJECT_ICON_NONE_FOUND = 'Geen pictogram gevonden';
