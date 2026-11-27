import type { VaultItem } from '~/types/vault';
import type { ValidationContact, ValidationOrganizationKind, ValidationPlace } from '~/types/verification';
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

/** "Tilburg" without a name; "Westermarkt, Tilburg" with one; "Tilburg-Noord" when the name already says the city. */
export function locationTitle(name: string | null | undefined, city: string) {
  const trimmed = name?.trim();
  if (!trimmed) return city;
  if (normalisedName(trimmed)?.includes(normalisedName(city) ?? '')) return trimmed;
  return `${trimmed}, ${city}`;
}

/** "Albert Heijn · Breda", "McDonald's · Westermarkt, Tilburg". */
export function placeTitle(place: ValidationPlace) {
  return `${place.organizationName} · ${locationTitle(place.locationName, place.city)}`;
}

/** "Bedrijf · Westermarkt, Tilburg" under the name; without the kind when the search already filters on it. */
export function placeDetails(place: ValidationPlace, showsKind = true) {
  return [showsKind ? organizationKindTitle(place.kind) : null, locationTitle(place.locationName, place.city)].filter(Boolean).join(' · ');
}

/** "Docent · HBO-ICT · Eindhoven", so two people with the same name differ; with the organisation for an earlier one. */
export function contactDetails(contact: ValidationContact, withOrganization = false) {
  const parts = [contact.function, contact.departmentName, locationTitle(contact.locationName, contact.city)];
  if (withOrganization && contact.organizationName) parts.push(contact.organizationName);
  return parts.filter(Boolean).join(' · ');
}

/** "AB", for a person without a photo. */
export function initialsOf(name: string) {
  return name
    .split(/\s+/)
    .filter(Boolean)
    .slice(0, 2)
    .map((part) => part[0]!.toUpperCase())
    .join('');
}

// Which location the evidence means (iOS VaultConfirmationRequest; keep the two the same). The app only chooses when it
// is certain; otherwise the learner chooses.

function words(text: string) {
  return text
    .split(/[^\p{L}-]+/u)
    .filter(Boolean)
    .join(' ');
}

/** "Heuvelstraat 12, 5038 AA Tilburg" to "Heuvelstraat 12". */
function streetOf(address: string | null) {
  return address?.split(',')[0] ?? null;
}

/**
 * The locations the text names, as whole words: by city, narrowed by the location's name or street when it names one.
 * A location name alone ("Tilburg-Noord", "Westermarkt") counts too when the text names no city of these.
 */
export function locatedPlaces(places: ValidationPlace[], typed: string | null | undefined) {
  const normalised = normalisedName(typed);
  if (!normalised) return [];
  const text = ` ${words(normalised)} `;
  const names = (value: string | null | undefined) => {
    const word = normalisedName(value);
    const clean = word ? words(word) : '';
    return Boolean(clean) && text.includes(` ${clean} `);
  };
  const inCity = places.filter((place) => names(place.city));
  const byName = (inCity.length ? inCity : places).filter((place) => names(place.locationName) || names(streetOf(place.address)));
  return byName.length ? byName : inCity;
}

/** The one location the text names, or null. */
function placeInText(places: ValidationPlace[], typed: string | null | undefined) {
  const found = locatedPlaces(places, typed);
  return found.length === 1 ? found[0]! : null;
}

/**
 * The location among these in the city the learner typed; without one, the one their description names, or else the
 * only one. A typed city where it has no location chooses nothing.
 */
export function onlyPlace(places: ValidationPlace[], typedCity: string | null | undefined, described?: string | null) {
  const typed = placeInText(places, typedCity);
  if (typed) return typed;
  if (normalisedName(typedCity)) return null;
  const inDescription = placeInText(places, described);
  if (inDescription) return inDescription;
  return places.length === 1 ? places[0]! : null;
}

/** "McDonald's Tilburg": what the search starts with when the city in the evidence has several of its locations. */
export function placeSearchHint(places: ValidationPlace[], item: VaultItem) {
  const text = normalisedName(item.organisationLocation) ? item.organisationLocation : item.description;
  const found = locatedPlaces(places, text);
  if (found.length < 2) return null;
  if (new Set(found.map((place) => place.organizationId)).size !== 1 || new Set(found.map((place) => place.city)).size !== 1) return null;
  return `${found[0]!.organizationName} ${found[0]!.city}`;
}

/** The location of an earlier request is certainly still right: it lies in the typed or described city, or none is named. */
export function fitsTypedCity(place: ValidationPlace, item: VaultItem) {
  if (normalisedName(item.organisationLocation)) return placeInText([place], item.organisationLocation) !== null;
  if (!normalisedName(item.description)) return true;
  return placeInText([place], item.description) !== null;
}

/** A suggestion from the typed name: the one location of the organisation with that name, or the one in the typed city. */
export function placeSuggestion(item: VaultItem, places: ValidationPlace[]) {
  const name = normalisedName(item.organisationName);
  if (!name) return null;
  const named = places.filter((place) => normalisedName(place.organizationName) === name);
  if (new Set(named.map((place) => place.organizationId)).size !== 1) return null;
  return onlyPlace(named, item.organisationLocation, item.description);
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
