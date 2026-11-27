export type ValidationOrganizationKind = 'school' | 'company' | 'government' | 'other';

/** An organisation where someone may confirm this kind of evidence (validation_search_organizations). */
export interface ValidationOrganization {
  id: string;
  name: string;
  kind: ValidationOrganizationKind;
  cities: string[];
  // How many persons there may confirm this kind of evidence; 0 for a known organisation where nobody may.
  availableContacts: number;
}

/**
 * A person a learner can ask, with where they work (validation_search_contacts). Which PAVE account is behind them
 * stays hidden (reviewer_id).
 */
export interface ValidationContact {
  id: string;
  name: string;
  jobTitle: string | null;
  // The job title, or "Overig" without one.
  function: string;
  departmentId: string;
  departmentName: string;
  locationId: string;
  city: string;
  organizationId: string;
  // Only for someone asked before, who may be of another organisation.
  organizationName: string | null;
}

/** A choice for the optional filters on persons (validation_contact_filters). */
export interface ValidationFilterOption {
  filter: 'location' | 'department' | 'function';
  value: string;
  label: string;
  // For a department: the location it belongs to.
  locationId: string | null;
}

/** Only narrow the list of persons; they are never sent. */
export interface ValidationFilters {
  locationId: string;
  departmentId: string;
  function: string;
}

/** What the learner chose, by ID only: location and department follow from the person; the server checks them again. */
export interface ValidationChoice {
  itemId: string;
  organizationId: string;
  locationId: string;
  departmentId: string;
  contactId: string;
}

/** The most recent request for an item, as the learner may read it back (vault_validation_requests). */
export interface VaultValidationRequest {
  status: 'pending' | 'verified' | 'rejected' | 'cancelled';
  organizationId: string | null;
  organisationName: string;
  requestedAt: string;
  response: string | null;
}
