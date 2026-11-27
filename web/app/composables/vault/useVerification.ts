import type { VaultItemCategory } from '~/types/vault';
import type {
  ValidationChoice,
  ValidationContact,
  ValidationFilterOption,
  ValidationFilters,
  ValidationOrganizationKind,
  ValidationPlace,
} from '~/types/verification';

// A page of 25, as on iOS; "Meer laden" asks for the next one.
const PAGE_SIZE = 25;
const KINDS: ValidationOrganizationKind[] = ['school', 'company', 'government', 'other'];
/** vault-review hands out at most 50 photos per question. */
const PHOTOS_PER_CALL = 50;

interface PlaceRow {
  organization_id: string;
  organization_name: string;
  kind: string | null;
  logo_url: string | null;
  location_id: string;
  city: string;
  location_name?: string | null;
  address?: string | null;
  available_contacts: number | null;
  total_count?: number | null;
}

interface ContactRow {
  id: string;
  name: string;
  job_title: string | null;
  function: string | null;
  department_id: string;
  department_name: string;
  location_id: string;
  city: string;
  location_name?: string | null;
  organization_id: string;
  organization_name?: string | null;
  total_count?: number | null;
}

interface FilterRow {
  filter: string;
  value: string;
  label: string;
  location_id: string | null;
  people?: number | null;
}

export interface ValidationPage<T> {
  rows: T[];
  total: number;
}

function toPlace(row: PlaceRow): ValidationPlace {
  const kind = KINDS.find((known) => known === row.kind) ?? 'other';
  return {
    organizationId: row.organization_id,
    organizationName: row.organization_name,
    kind,
    logoUrl: row.logo_url?.startsWith('https://') ? row.logo_url : null,
    locationId: row.location_id,
    city: row.city,
    locationName: row.location_name?.trim() || null,
    address: row.address?.trim() || null,
    availableContacts: row.available_contacts ?? 0,
  };
}

function toContact(row: ContactRow): ValidationContact {
  return {
    id: row.id,
    name: row.name,
    jobTitle: row.job_title,
    function: row.function?.trim() || row.job_title?.trim() || REQUEST_OTHER_FUNCTION,
    departmentId: row.department_id,
    departmentName: row.department_name,
    locationId: row.location_id,
    city: row.city,
    locationName: row.location_name?.trim() || null,
    organizationId: row.organization_id,
    organizationName: row.organization_name ?? null,
  };
}

function toFilterOption(row: FilterRow): ValidationFilterOption | null {
  if (row.filter !== 'location' && row.filter !== 'department' && row.filter !== 'function') return null;
  return { filter: row.filter, value: row.value, label: row.label, locationId: row.location_id, people: row.people ?? 0 };
}

function toPage<Row extends { total_count?: number | null }, T>(rows: Row[], map: (row: Row) => T): ValidationPage<T> {
  return { rows: rows.map(map), total: Number(rows[0]?.total_count ?? rows.length) };
}

/**
 * Asking an organisation to confirm evidence (iOS VaultService, docs/verificatie.md). The learner picks an organisation
 * with one of its locations ("Albert Heijn · Breda") and then a person there. The directory is searched through the
 * validation_* functions, which only show persons who may confirm this kind of evidence; the request itself is made by
 * vault-review, which checks the choice again.
 */
export function useVerification() {
  const supabase = useUntypedSupabase();
  const { call } = useVaultReview();
  const vault = useVault();

  /**
   * Locations where someone may confirm it, searched on organisation, city, location name and address; optionally of
   * one kind ("Onderwijs", "Bedrijven"…) or of one organisation (the one the evidence names).
   */
  async function searchPlaces(
    category: VaultItemCategory,
    query: string,
    kind: ValidationOrganizationKind | null,
    organizationId: string | null = null,
    offset = 0,
  ) {
    const { data, error } = await supabase.rpc('validation_search_places', {
      p_category: category,
      p_query: query.trim() || null,
      p_kind: kind,
      p_organization_id: organizationId,
      p_limit: PAGE_SIZE,
      p_offset: offset,
    });
    if (error || !data) return { data: null, error: REQUEST_LOAD_FAILED.organizations };
    return { data: toPage(data as PlaceRow[], toPlace), error: null };
  }

  /** Locations known by ID (from an earlier request), also when nobody there may confirm it any more. */
  async function placesById(category: VaultItemCategory, locationIds: string[]) {
    if (!locationIds.length) return { data: [] as ValidationPlace[], error: null };
    const { data, error } = await supabase.rpc('validation_places_by_id', { p_category: category, p_location_ids: locationIds });
    if (error || !data) return { data: null, error: REQUEST_LOAD_FAILED.organizations };
    return { data: (data as PlaceRow[]).map(toPlace), error: null };
  }

  /** The persons at one location, searched on name and function, optionally of one department and function. */
  async function searchContacts(place: ValidationPlace, category: VaultItemCategory, query: string, filters: ValidationFilters, offset = 0) {
    const { data, error } = await supabase.rpc('validation_search_contacts', {
      p_organization_id: place.organizationId,
      p_category: category,
      p_query: query.trim() || null,
      p_location_id: place.locationId,
      p_department: filters.department || null,
      p_function: filters.function || null,
      p_limit: PAGE_SIZE,
      p_offset: offset,
    });
    if (error || !data) return { data: null, error: REQUEST_LOAD_FAILED.contacts };
    return { data: toPage(data as ContactRow[], toContact), error: null };
  }

  async function contactFilters(organizationId: string, category: VaultItemCategory) {
    const { data, error } = await supabase.rpc('validation_contact_filters', {
      p_organization_id: organizationId,
      p_category: category,
    });
    if (error || !data) return [];
    return (data as FilterRow[]).map(toFilterOption).filter((option): option is ValidationFilterOption => option !== null);
  }

  /** Whom the learner asked before and who may still confirm this kind of evidence, most recent first. */
  async function previousContacts(category: VaultItemCategory) {
    const { data, error } = await supabase.rpc('validation_previous_contacts', { p_category: category, p_limit: 5 });
    if (error || !data) return [];
    return (data as ContactRow[]).map(toContact);
  }

  /** The profile photos of these persons, as links valid for an hour; persons without a photo are left out. */
  async function contactPhotos(contactIds: string[]) {
    const photos: Record<string, string> = {};
    for (let start = 0; start < contactIds.length; start += PHOTOS_PER_CALL) {
      const { data } = await call<{ photos: Record<string, string> }>('contactPhotos', {
        contactIds: contactIds.slice(start, start + PHOTOS_PER_CALL),
      });
      for (const [id, url] of Object.entries(data?.photos ?? {})) if (url.startsWith('https://')) photos[id] = url;
    }
    return photos;
  }

  /** Sends the request and reads the vault again, so the item shows "In afwachting". */
  async function sendRequest(choice: ValidationChoice) {
    const { errorCode } = await call('create', { ...choice, message: '' });
    if (errorCode) return { error: functionErrorMessage(errorCode, REQUEST_SEND_FAILED) };
    await vault.load();
    return { error: null };
  }

  return { searchPlaces, placesById, searchContacts, contactFilters, previousContacts, contactPhotos, sendRequest };
}
