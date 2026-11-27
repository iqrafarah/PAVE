import type { VaultItem, VaultItemCategory } from '~/types/vault';
import type {
  ValidationChoice,
  ValidationContact,
  ValidationFilterOption,
  ValidationFilters,
  ValidationOrganizationKind,
  ValidationPlace,
} from '~/types/verification';

export type ValidationField = keyof typeof REQUEST_MISSING;

// Typing waits a moment, so not every letter goes to the database (as on iOS).
const SEARCH_DELAY_MS = 300;

function emptyFilters(): ValidationFilters {
  return { department: '', function: '' };
}

/**
 * "Bevestiging aanvragen" (iOS VaultConfirmationRequest and VaultRequestConfirmationSheet): an organisation with one of
 * its locations in one go ("Albert Heijn · Breda"), then one person there. The location comes from an earlier request
 * or from the organisation of the evidence by its ID, at the city the evidence names; a typed name only suggests one.
 * Department and function only narrow the persons; the request goes to the chosen person.
 */
export function useValidationForm() {
  const directory = useVerification();

  const category = ref<VaultItemCategory | null>(null);
  const place = ref<ValidationPlace | null>(null);
  const suggestion = ref<ValidationPlace | null>(null);
  /** What the place search starts with: the organisation of the evidence, when its location is not certain. */
  const suggestedSearch = ref('');
  const isStarting = ref(false);
  const previousPeople = ref<ValidationContact[]>([]);
  const people = ref<ValidationContact[]>([]);
  const peopleTotal = ref(0);
  const isLoadingPeople = ref(false);
  const isLoadingMorePeople = ref(false);
  const filterOptions = ref<ValidationFilterOption[]>([]);
  const filters = ref<ValidationFilters>(emptyFilters());
  const search = ref('');
  const contact = ref<ValidationContact | null>(null);
  /** Profile photos by contact person, fetched for the persons on screen. */
  const photos = ref<Record<string, string>>({});
  // Something was chosen by hand: closing then asks "Verzoek weggooien?".
  const isDirty = ref(false);
  const directoryError = ref<string | null>(null);

  // The place search (iOS VaultOrganizationSearchSheet): organisation, place or address, and Alles or one kind.
  const placeQuery = ref('');
  const placeKind = ref<ValidationOrganizationKind | null>(null);
  const places = ref<ValidationPlace[]>([]);
  const placeTotal = ref(0);
  const isLoadingPlaces = ref(false);
  const isLoadingMorePlaces = ref(false);
  const placesFailed = ref(false);

  // Each search gets a number; an answer to an older one is ignored, so a slow answer never overwrites a newer one.
  let peopleSearch = 0;
  let placeSearch = 0;
  let peopleTimer: ReturnType<typeof setTimeout> | undefined;
  let placeTimer: ReturnType<typeof setTimeout> | undefined;
  const photosAsked = new Set<string>();

  const missingFields = computed(() => {
    const fields: ValidationField[] = [];
    if (!place.value) fields.push('organization');
    if (!contact.value) fields.push('contact');
    return fields;
  });

  const hasFilters = computed(() => Boolean(filters.value.department || filters.value.function));
  const isBrowsing = computed(() => !search.value.trim() && !hasFilters.value);
  /** Whom you asked before at this location, on top while you have not searched or filtered. */
  const previousHere = computed(() =>
    isBrowsing.value && place.value ? previousPeople.value.filter((person) => person.locationId === place.value?.locationId) : [],
  );
  const otherPeople = computed(() => people.value.filter((person) => !previousHere.value.some((previous) => previous.id === person.id)));

  /** The departments or functions at the chosen location, each name once. */
  function optionsAt(filter: 'department' | 'function') {
    const locationId = place.value?.locationId;
    const shown = filterOptions.value.filter((option) => option.filter === filter && (!option.locationId || !locationId || option.locationId === locationId));
    const labels = [...new Set(shown.map((option) => option.label))];
    return labels.sort((a, b) => a.localeCompare(b, 'nl')).map((label) => ({ value: label, label }));
  }
  const departmentOptions = computed(() => optionsAt('department'));
  const functionOptions = computed(() => optionsAt('function'));

  async function loadPhotos() {
    const missing = [...people.value, ...previousPeople.value].map((person) => person.id).filter((id) => !photosAsked.has(id));
    if (!missing.length) return;
    for (const id of missing) photosAsked.add(id);
    const found = await directory.contactPhotos(missing);
    photos.value = { ...photos.value, ...found };
  }

  async function loadPeople() {
    const chosen = place.value;
    if (!chosen || !category.value) {
      people.value = [];
      peopleTotal.value = 0;
      return;
    }
    const current = ++peopleSearch;
    isLoadingPeople.value = true;
    const result = await directory.searchContacts(chosen, category.value, search.value, filters.value);
    if (current !== peopleSearch) return;
    isLoadingPeople.value = false;
    if (result.error) {
      directoryError.value = result.error;
      return;
    }
    directoryError.value = null;
    people.value = result.data?.rows ?? [];
    peopleTotal.value = result.data?.total ?? 0;
    loadPhotos();
  }

  async function loadMorePeople() {
    const chosen = place.value;
    if (!chosen || !category.value || isLoadingMorePeople.value) return;
    const current = peopleSearch;
    isLoadingMorePeople.value = true;
    const result = await directory.searchContacts(chosen, category.value, search.value, filters.value, people.value.length);
    isLoadingMorePeople.value = false;
    if (current !== peopleSearch || !result.data) return;
    const added = result.data.rows.filter((row) => !people.value.some((person) => person.id === row.id));
    people.value = [...people.value, ...added];
    peopleTotal.value = result.data.total;
    loadPhotos();
  }

  function setSearch(text: string) {
    search.value = text;
    clearTimeout(peopleTimer);
    peopleTimer = setTimeout(loadPeople, SEARCH_DELAY_MS);
  }

  /** A filter never clears the chosen person. */
  function setFilter(name: keyof ValidationFilters, value: string) {
    filters.value = { ...filters.value, [name]: value };
    loadPeople();
  }

  function clearFilters() {
    filters.value = emptyFilters();
    loadPeople();
  }

  /** Another location: the person, the search and the filters belong to the old one, so they go. */
  async function choosePlace(next: ValidationPlace) {
    if (next.locationId === place.value?.locationId) return;
    const sameOrganization = next.organizationId === place.value?.organizationId;
    place.value = next;
    contact.value = null;
    search.value = '';
    filters.value = emptyFilters();
    people.value = [];
    peopleTotal.value = 0;
    if (!sameOrganization) filterOptions.value = [];
    if (!category.value || next.availableContacts === 0) return;
    const [options] = await Promise.all([
      sameOrganization ? Promise.resolve(filterOptions.value) : directory.contactFilters(next.organizationId, category.value),
      loadPeople(),
    ]);
    if (next.locationId === place.value?.locationId) filterOptions.value = options;
  }

  function pickPlace(next: ValidationPlace) {
    if (next.locationId !== place.value?.locationId) isDirty.value = true;
    return choosePlace(next);
  }

  /** An earlier contact elsewhere brings their organisation and location along. */
  async function choosePerson(person: ValidationContact) {
    isDirty.value = true;
    if (person.locationId !== place.value?.locationId && category.value) {
      await choosePlace({
        organizationId: person.organizationId,
        organizationName: person.organizationName ?? '',
        kind: 'other',
        logoUrl: null,
        locationId: person.locationId,
        city: person.city,
        locationName: person.locationName,
        address: null,
        availableContacts: 1,
      });
      // Fills in kind, logo and address.
      const found = await directory.placesById(category.value, [person.locationId]);
      const real = found.data?.[0];
      if (real && place.value?.locationId === real.locationId) place.value = real;
    }
    contact.value = person;
  }

  async function loadPlaces() {
    if (!category.value) return;
    const current = ++placeSearch;
    isLoadingPlaces.value = true;
    const result = await directory.searchPlaces(category.value, placeQuery.value, placeKind.value);
    if (current !== placeSearch) return;
    isLoadingPlaces.value = false;
    placesFailed.value = Boolean(result.error);
    places.value = result.data?.rows ?? [];
    placeTotal.value = result.data?.total ?? 0;
  }

  function searchPlaces(text: string) {
    placeQuery.value = text;
    clearTimeout(placeTimer);
    placeTimer = setTimeout(loadPlaces, text.trim() ? SEARCH_DELAY_MS : 0);
  }

  function setPlaceKind(kind: ValidationOrganizationKind | null) {
    placeKind.value = kind;
    clearTimeout(placeTimer);
    loadPlaces();
  }

  async function loadMorePlaces() {
    if (!category.value || isLoadingMorePlaces.value || places.value.length >= placeTotal.value) return;
    const current = placeSearch;
    isLoadingMorePlaces.value = true;
    const result = await directory.searchPlaces(category.value, placeQuery.value, placeKind.value, null, places.value.length);
    isLoadingMorePlaces.value = false;
    if (current !== placeSearch || !result.data) return;
    const added = result.data.rows.filter((row) => !places.value.some((entry) => entry.locationId === row.locationId));
    places.value = [...places.value, ...added];
    placeTotal.value = result.data.total;
  }

  /** The search opens with the organisation of the evidence when no location is chosen yet, otherwise empty. */
  function openPlaceSearch() {
    placeQuery.value = place.value ? '' : suggestedSearch.value;
    placeKind.value = null;
    loadPlaces();
  }

  /**
   * The location of an earlier request when it still fits the city the evidence names; otherwise the organisation of
   * the evidence (or of the earlier request) by ID, at the city the evidence names. Then the earlier location after
   * all. Without any of that a suggestion from the typed name. And who the learner asked before.
   */
  async function start(item: VaultItem) {
    clearTimeout(peopleTimer);
    clearTimeout(placeTimer);
    peopleSearch++;
    category.value = item.category;
    place.value = null;
    suggestion.value = null;
    suggestedSearch.value = '';
    contact.value = null;
    people.value = [];
    peopleTotal.value = 0;
    filterOptions.value = [];
    filters.value = emptyFilters();
    search.value = '';
    isDirty.value = false;
    directoryError.value = null;
    isStarting.value = true;

    const previous = directory.previousContacts(item.category);
    let chosen: ValidationPlace | null = null;
    let earlier: ValidationPlace | null = null;
    let hint = '';
    let failed = false;

    if (item.lastRequest?.locationId) {
      const found = await directory.placesById(item.category, [item.lastRequest.locationId]);
      if (found.error) failed = true;
      earlier = found.data?.[0] ?? null;
      if (earlier && fitsTypedCity(earlier, item)) chosen = earlier;
    }
    const knownOrganizations = [item.organizationId, item.lastRequest?.organizationId].filter(
      (id, index, all): id is string => Boolean(id) && all.indexOf(id) === index,
    );
    for (const organizationId of knownOrganizations) {
      if (chosen) break;
      const page = await directory.searchPlaces(item.category, '', null, organizationId);
      if (page.error) failed = true;
      const rows = page.data?.rows ?? [];
      chosen = onlyPlace(rows, item.organisationLocation, item.description);
      // Two locations in the typed city: the search lists just those.
      if (!chosen && rows[0] && !hint) hint = placeSearchHint(rows, item) ?? rows[0].organizationName;
    }
    // The typed city is not one of its locations: then the earlier request after all.
    if (!chosen && earlier) chosen = earlier;
    if (!chosen && !hint && item.organisationName?.trim()) {
      const page = await directory.searchPlaces(item.category, item.organisationName, null);
      if (page.error) failed = true;
      const rows = page.data?.rows ?? [];
      suggestion.value = placeSuggestion(item, rows);
      if (!suggestion.value) {
        const name = normalisedName(item.organisationName);
        hint = placeSearchHint(rows.filter((row) => normalisedName(row.organizationName) === name), item) ?? '';
      }
    }
    suggestedSearch.value = hint;
    if (failed && !chosen) directoryError.value = REQUEST_LOAD_FAILED.organizations;
    if (chosen) await choosePlace(chosen);
    previousPeople.value = await previous;
    isStarting.value = false;
    loadPhotos();
  }

  function toChoice(itemId: string): ValidationChoice | null {
    if (!place.value || !contact.value) return null;
    return {
      itemId,
      organizationId: place.value.organizationId,
      locationId: contact.value.locationId,
      departmentId: contact.value.departmentId,
      contactId: contact.value.id,
    };
  }

  return {
    place,
    suggestion,
    suggestedSearch,
    isStarting,
    previousPeople,
    previousHere,
    otherPeople,
    people,
    peopleTotal,
    isLoadingPeople,
    isLoadingMorePeople,
    departmentOptions,
    functionOptions,
    filters,
    hasFilters,
    search,
    contact,
    photos,
    isDirty,
    directoryError,
    missingFields,
    placeQuery,
    placeKind,
    places,
    placeTotal,
    isLoadingPlaces,
    isLoadingMorePlaces,
    placesFailed,
    start,
    pickPlace,
    choosePerson,
    setSearch,
    setFilter,
    clearFilters,
    loadMorePeople,
    openPlaceSearch,
    searchPlaces,
    setPlaceKind,
    loadMorePlaces,
    toChoice,
  };
}
