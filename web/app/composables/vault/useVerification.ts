import type { VaultItemCategory } from '~/types/vault';
import type {
  ValidationChoice,
  ValidationContact,
  ValidationFilterOption,
  ValidationFilters,
  ValidationOrganization,
  ValidationOrganizationKind,
} from '~/types/verification';

// A page of 25, as on iOS; "Meer laden" asks for the next one.
const PAGE_SIZE = 25;
const KINDS: ValidationOrganizationKind[] = ['school', 'company', 'government', 'other'];

interface OrganizationRow {
  id: string;
  name: string;
  kind: string | null;
  cities: string[] | null;
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
  organization_id: string;
  organization_name?: string | null;
  total_count?: number | null;
}

interface FilterRow {
  filter: string;
  value: string;
  label: string;
  location_id: string | null;
}

export interface ValidationPage<T> {
  rows: T[];
  total: number;
}

function toOrganization(row: OrganizationRow): ValidationOrganization {
  const kind = KINDS.find((known) => known === row.kind) ?? 'other';
  return { id: row.id, name: row.name, kind, cities: row.cities ?? [], availableContacts: row.available_contacts ?? 0 };
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
    organizationId: row.organization_id,
    organizationName: row.organization_name ?? null,
  };
}

function toFilterOption(row: FilterRow): ValidationFilterOption | null {
  if (row.filter !== 'location' && row.filter !== 'department' && row.filter !== 'function') return null;
  return { filter: row.filter, value: row.value, label: row.label, locationId: row.location_id };
}

function toPage<Row extends { total_count?: number | null }, T>(rows: Row[], map: (row: Row) => T): ValidationPage<T> {
  return { rows: rows.map(map), total: Number(rows[0]?.total_count ?? rows.length) };
}

/**
 * Asking an organisation to confirm evidence (iOS VaultModel, docs/verificatie.md). The directory is searched through
 * the validation_* functions, which only show persons who may confirm this kind of evidence; the request itself is
 * made by vault-review, which checks the choice again.
 */
export function useVerification() {
  const supabase = useUntypedSupabase();
  const { call } = useVaultReview();
  const vault = useVault();

  /** Organisations where someone may confirm it, on name, optionally of one kind ("Onderwijs", "Bedrijven"…). */
  async function searchOrganizations(category: VaultItemCategory, query: string, kind: ValidationOrganizationKind | null, offset = 0) {
    const { data, error } = await supabase.rpc('validation_search_organizations', {
      p_category: category,
      p_query: query.trim() || null,
      p_kind: kind,
      p_limit: PAGE_SIZE,
      p_offset: offset,
    });
    if (error || !data) return { data: null, error: REQUEST_LOAD_FAILED.organizations };
    return { data: toPage(data as OrganizationRow[], toOrganization), error: null };
  }

  /** The organisation of the evidence or of an earlier request, also when nobody there may confirm it. */
  async function organizationsById(category: VaultItemCategory, ids: string[]) {
    if (!ids.length) return { data: [] as ValidationOrganization[], error: null };
    const { data, error } = await supabase.rpc('validation_organizations_by_id', { p_category: category, p_ids: ids });
    if (error || !data) return { data: null, error: REQUEST_LOAD_FAILED.organizations };
    return { data: (data as OrganizationRow[]).map(toOrganization), error: null };
  }

  async function searchContacts(
    organizationId: string,
    category: VaultItemCategory,
    query: string,
    filters: ValidationFilters,
    offset = 0,
  ) {
    const parameters = {
      p_organization_id: organizationId,
      p_category: category,
      p_query: query.trim() || null,
      p_location_id: filters.locationId || null,
      p_function: filters.function || null,
      p_limit: PAGE_SIZE,
      p_offset: offset,
    };
    const department = filters.departmentId || null;
    let { data, error } = await supabase.rpc('validation_search_contacts', { ...parameters, p_department_id: department });
    // A database with an older version of migration 20261124120000 calls it p_department. PGRST202: no function with
    // these parameter names; then the older name is tried.
    if (error?.code === 'PGRST202') {
      ({ data, error } = await supabase.rpc('validation_search_contacts', { ...parameters, p_department: department }));
    }
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

  /** Sends the request and reads the vault again, so the item shows "In afwachting". */
  async function sendRequest(choice: ValidationChoice) {
    const { errorCode } = await call('create', { ...choice, message: '' });
    if (errorCode) return { error: functionErrorMessage(errorCode, REQUEST_SEND_FAILED) };
    await vault.load();
    return { error: null };
  }

  return { searchOrganizations, organizationsById, searchContacts, contactFilters, previousContacts, sendRequest };
}
