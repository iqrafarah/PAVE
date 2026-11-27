import type { VaultItem } from '~/types/vault';
import type { ValidationContact, ValidationOrganization, ValidationOrganizationKind } from '~/types/verification';
import {
  REQUEST_KIND_TITLES,
  REQUEST_SHARED_DESCRIPTION,
  REQUEST_SHARED_FILES,
  REQUEST_SHARED_SKILLS,
} from './verificationMessages';

/** A request is open: shown as "In afwachting", and a new one cannot be sent until it is decided. */
export function isAwaitingReview(item: VaultItem) {
  return item.status === 'toVerify' && item.lastRequest?.status === 'pending';
}

/** Why the item was rejected, while it still is. */
export function rejectionReason(item: VaultItem) {
  if (item.status !== 'rejected' || item.lastRequest?.status !== 'rejected') return null;
  const reason = item.lastRequest.response?.trim();
  return reason || null;
}

/** Confirmed evidence first has to change; while a request is open the reviewer decides first. */
export function canRequestConfirmation(item: VaultItem) {
  return item.status !== 'verified' && !isAwaitingReview(item);
}

/** For comparing names: case, accents and extra spaces do not count (iOS VaultConfirmationRequest.normalised). */
export function normalisedName(text: string | null | undefined) {
  const value = (text ?? '')
    .normalize('NFD')
    .replace(/\p{Diacritic}/gu, '')
    .toLocaleLowerCase('nl')
    .split(/\s+/)
    .filter(Boolean)
    .join(' ');
  return value || null;
}

/** "Onderwijs", "Bedrijf", "Overheid" or "Overig", as on iOS. */
export function organizationKindTitle(kind: ValidationOrganizationKind) {
  return REQUEST_KIND_TITLES[kind];
}

/** "Eindhoven, Tilburg +3". */
export function organizationCities(organization: ValidationOrganization) {
  const { cities } = organization;
  if (!cities.length) return null;
  const shown = cities.slice(0, 2).join(', ');
  return cities.length > 2 ? `${shown} +${cities.length - 2}` : shown;
}

/** "Onderwijs · Eindhoven, Tilburg +3", under the name of an organisation. */
export function organizationDetails(organization: ValidationOrganization, showsKind = true) {
  return [showsKind ? organizationKindTitle(organization.kind) : null, organizationCities(organization)].filter(Boolean).join(' · ');
}

/** Function, department and location, so two people with the same name differ; with the organisation for an earlier one. */
export function contactDetails(contact: ValidationContact, withOrganization = false) {
  const parts = [contact.function, contact.departmentName, contact.city];
  if (withOrganization && contact.organizationName) parts.push(contact.organizationName);
  return parts.filter(Boolean).join(' · ');
}

/** "Met omschrijving, 2 bestanden en 3 vaardigheden": what is shared along with the evidence (iOS sharedLine). */
export function sharedLine(item: VaultItem) {
  const parts: string[] = [];
  if (item.description?.trim()) parts.push(REQUEST_SHARED_DESCRIPTION);
  const documents = item.files.filter((file) => file.role === 'document').length;
  if (documents) parts.push(REQUEST_SHARED_FILES(documents));
  if (item.skills.length) parts.push(REQUEST_SHARED_SKILLS(item.skills.length));
  const last = parts.pop();
  if (!last) return null;
  return `Met ${parts.length ? `${parts.join(', ')} en ${last}` : last}`;
}
