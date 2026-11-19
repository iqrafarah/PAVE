import type { PaveIconName } from './paveIcons';
import { MEMORY_PAGE_PATH } from '../ayla/aylaScreens';

export interface MainPlace {
  label: string;
  path: string;
  // The pixel A for Ayla; an icon for the rest.
  icon: PaveIconName | 'ayla';
  // Shown instead of `icon` while the place is open (Kluis: the open folder).
  activeIcon?: PaveIconName;
}

/** The places at the top of the menu, in the iPhone's order (iOS MainDestination.main). */
export const MAIN_PLACES: MainPlace[] = [
  { label: 'Ayla', path: '/', icon: 'ayla' },
  { label: 'Kluis', path: '/kluis', icon: 'folderClosed', activeIcon: 'folder' },
  { label: 'Plan', path: '/plan', icon: 'map' },
  { label: 'Profiel', path: '/profiel', icon: 'person' },
];

/** Ayla is open on the home screen and in a chat, but not on "Wat Ayla over je weet" (part of the settings). */
export function isPlaceActive(place: MainPlace, path: string) {
  if (place.path === '/') return path === '/' || (path.startsWith('/ayla') && path !== MEMORY_PAGE_PATH);
  return path.startsWith(place.path);
}

export function placeIcon(place: MainPlace, path: string) {
  return place.activeIcon && isPlaceActive(place, path) ? place.activeIcon : place.icon;
}
