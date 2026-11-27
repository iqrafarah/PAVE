import type { VaultItem, VaultItemCategory } from '~/types/vault';
import type {
  ValidationChoice,
  ValidationContact,
  ValidationFilterOption,
  ValidationFilters,
  ValidationOrganization,
  ValidationOrganizationKind,
} from '~/types/verification';

export type ValidationField = keyof typeof REQUEST_MISSING;

// Typing waits a moment, so not every letter goes to the database (as on iOS).
const SEARCH_DELAY_MS = 300;

function emptyFilters(): ValidationFilters {
  return { locationId: '', departmentId: '', function: '' };
}

/**
 * "Bevestiging aanvragen" (iOS VaultConfirmationRequest and VaultRequestConfirmationSheet): an organisation, then one
 * person. The organisation comes from the evidence by its ID; a typed name only suggests one ("Bedoel je …?").
 * Location, department and function only narrow the list of persons; the request goes to the chosen person, and their
 * location and department go along.
 */
export function useValidationForm() {
  const directory = useVerification();

  const category = ref<VaultItemCategory | null>(null);
  const organization = ref<ValidationOrganization | null>(null);
  const suggestion = ref<ValidationOrganization | null>(null);
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
  // Something was chosen by hand: closing then asks "Verzoek weggooien?".
  const isDirty = ref(false);
  const directoryError = ref<string | null>(null);

  // The organisation search (iOS VaultOrganizationSearchSheet): a name, and Alles or one kind.
  const organizationQuery = ref('');
  const organizationKind = ref<ValidationOrganizationKind | null>(null);
  const organizations = ref<ValidationOrganization[]>([]);
  const organizationTotal = ref(0);
  const isLoadingOrganizations = ref(false);
  const isLoadingMoreOrganizations = ref(false);
  const organizationsFailed = ref(false);

  // Each search gets a number; an answer to an older one is ignored, so a slow answer never overwrites a newer one.
  let peopleSearch = 0;
  let organizationSearch = 0;
  let peopleTimer: ReturnType<typeof setTimeout> | undefined;
  let organizationTimer: ReturnType<typeof setTimeout> | undefined;

  const missingFields = computed(() => {
    const fields: ValidationField[] = [];
    if (!organization.value) fields.push('organization');
    if (!contact.value) fields.push('contact');
    return fields;
  });

  const hasFilters = computed(() => Boolean(filters.value.locationId || filters.value.departmentId || filters.value.function));
  const isBrowsing = computed(() => !search.value.trim() && !hasFilters.value);
  /** Whom you asked before at this organisation, on top while you have not searched or filtered. */
  const previousHere = computed(() =>
    isBrowsing.value && organization.value ? previousPeople.value.filter((person) => person.organizationId === organization.value?.id) : [],
  );
  const otherPeople = computed(() => people.value.filter((person) => !previousHere.value.some((previous) => previous.id === person.id)));

  async function loadPeople() {
    const chosen = organization.value;
    if (!chosen || !category.value) {
      people.value = [];
      peopleTotal.value = 0;
      return;
    }
    const current = ++peopleSearch;
    isLoadingPeople.value = true;
    const result = await directory.searchContacts(chosen.id, category.value, search.value, filters.value);
    if (current !== peopleSearch) return;
    isLoadingPeople.value = false;
    if (result.error) {
      directoryError.value = result.error;
      return;
    }
    directoryError.value = null;
    people.value = result.data?.rows ?? [];
    peopleTotal.value = result.data?.total ?? 0;
  }

  async function loadMorePeople() {
    const chosen = organization.value;
    if (!chosen || !category.value || isLoadingMorePeople.value) return;
    const current = peopleSearch;
    isLoadingMorePeople.value = true;
    const result = await directory.searchContacts(chosen.id, category.value, search.value, filters.value, people.value.length);
    isLoadingMorePeople.value = false;
    if (current !== peopleSearch || !result.data) return;
    const added = result.data.rows.filter((row) => !people.value.some((person) => person.id === row.id));
    people.value = [...people.value, ...added];
    peopleTotal.value = result.data.total;
  }

  function setSearch(text: string) {
    search.value = text;
    clearTimeout(peopleTimer);
    peopleTimer = setTimeout(loadPeople, SEARCH_DELAY_MS);
  }

  /** A department of another location goes when the location changes; a filter never clears the chosen person. */
  function setFilter(name: keyof ValidationFilters, value: string) {
    const next = { ...filters.value, [name]: value };
    if (name === 'locationId' && value && next.departmentId) {
      const fits = filterOptions.value.some(
        (option) => option.filter === 'department' && option.value === next.departmentId && option.locationId === value,
      );
      if (!fits) next.departmentId = '';
    }
    filters.value = next;
    loadPeople();
  }

  function clearFilters() {
    filters.value = emptyFilters();
    loadPeople();
  }

  /** Another organisation: the person, the search and the filters belong to the old one, so they go. */
  async function chooseOrganization(next: ValidationOrganization) {
    if (next.id === organization.value?.id) return;
    organization.value = next;
    contact.value = null;
    search.value = '';
    filters.value = emptyFilters();
    filterOptions.value = [];
    people.value = [];
    peopleTotal.value = 0;
    if (!category.value || next.availableContacts === 0) return;
    const [options] = await Promise.all([directory.contactFilters(next.id, category.value), loadPeople()]);
    if (next.id === organization.value?.id) filterOptions.value = options;
  }

  function pickOrganization(next: ValidationOrganization) {
    if (next.id !== organization.value?.id) isDirty.value = true;
    return chooseOrganization(next);
  }

  /** An earlier contact of another organisation brings that organisation along. */
  async function choosePerson(person: ValidationContact) {
    isDirty.value = true;
    if (person.organizationId !== organization.value?.id && category.value) {
      await chooseOrganization({
        id: person.organizationId,
        name: person.organizationName ?? '',
        kind: 'other',
        cities: [person.city],
        availableContacts: 1,
      });
      // Fills in kind and cities.
      const found = await directory.organizationsById(category.value, [person.organizationId]);
      const real = found.data?.[0];
      if (real && organization.value?.id === real.id) organization.value = real;
    }
    contact.value = person;
  }

  async function loadOrganizations() {
    if (!category.value) return;
    const current = ++organizationSearch;
    isLoadingOrganizations.value = true;
    const result = await directory.searchOrganizations(category.value, organizationQuery.value, organizationKind.value);
    if (current !== organizationSearch) return;
    isLoadingOrganizations.value = false;
    organizationsFailed.value = Boolean(result.error);
    organizations.value = result.data?.rows ?? [];
    organizationTotal.value = result.data?.total ?? 0;
  }

  function searchOrganizations(text: string) {
    organizationQuery.value = text;
    clearTimeout(organizationTimer);
    organizationTimer = setTimeout(loadOrganizations, text.trim() ? SEARCH_DELAY_MS : 0);
  }

  function setOrganizationKind(kind: ValidationOrganizationKind | null) {
    organizationKind.value = kind;
    clearTimeout(organizationTimer);
    loadOrganizations();
  }

  async function loadMoreOrganizations() {
    if (!category.value || isLoadingMoreOrganizations.value || organizations.value.length >= organizationTotal.value) return;
    const current = organizationSearch;
    isLoadingMoreOrganizations.value = true;
    const result = await directory.searchOrganizations(
      category.value,
      organizationQuery.value,
      organizationKind.value,
      organizations.value.length,
    );
    isLoadingMoreOrganizations.value = false;
    if (current !== organizationSearch || !result.data) return;
    const added = result.data.rows.filter((row) => !organizations.value.some((entry) => entry.id === row.id));
    organizations.value = [...organizations.value, ...added];
    organizationTotal.value = result.data.total;
  }

  /** The organisation search starts empty each time it opens. */
  function openOrganizationSearch() {
    organizationQuery.value = '';
    organizationKind.value = null;
    loadOrganizations();
  }

  /**
   * The organisation by ID when the evidence or an earlier request names one: the first where someone may confirm it,
   * otherwise simply the first. Without one, a suggestion from the typed name when exactly one organisation has it.
   * And who the learner asked before.
   */
  async function start(item: VaultItem) {
    clearTimeout(peopleTimer);
    clearTimeout(organizationTimer);
    peopleSearch++;
    category.value = item.category;
    organization.value = null;
    suggestion.value = null;
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
    const known = [item.organizationId, item.lastRequest?.organizationId].filter(
      (id, index, all): id is string => Boolean(id) && all.indexOf(id) === index,
    );
    const found = await directory.organizationsById(item.category, known);
    if (found.error) directoryError.value = found.error;
    const ranked = known.map((id) => found.data?.find((entry) => entry.id === id)).filter((entry) => entry !== undefined);
    const first = ranked.find((entry) => entry.availableContacts > 0) ?? ranked[0];
    if (first) {
      await chooseOrganization(first);
    } else {
      const name = normalisedName(item.organisationName);
      if (name) {
        const page = await directory.searchOrganizations(item.category, item.organisationName ?? '', null);
        const sameName = (page.data?.rows ?? []).filter((entry) => normalisedName(entry.name) === name);
        if (sameName.length === 1) suggestion.value = sameName[0]!;
      }
    }
    previousPeople.value = await previous;
    isStarting.value = false;
  }

  function toChoice(itemId: string): ValidationChoice | null {
    if (!organization.value || !contact.value) return null;
    return {
      itemId,
      organizationId: organization.value.id,
      locationId: contact.value.locationId,
      departmentId: contact.value.departmentId,
      contactId: contact.value.id,
    };
  }

  return {
    organization,
    suggestion,
    isStarting,
    previousPeople,
    previousHere,
    otherPeople,
    people,
    peopleTotal,
    isLoadingPeople,
    isLoadingMorePeople,
    filterOptions,
    filters,
    hasFilters,
    search,
    contact,
    isDirty,
    directoryError,
    missingFields,
    organizationQuery,
    organizationKind,
    organizations,
    organizationTotal,
    isLoadingOrganizations,
    isLoadingMoreOrganizations,
    organizationsFailed,
    start,
    pickOrganization,
    choosePerson,
    setSearch,
    setFilter,
    clearFilters,
    loadMorePeople,
    openOrganizationSearch,
    searchOrganizations,
    setOrganizationKind,
    loadMoreOrganizations,
    toChoice,
  };
}
