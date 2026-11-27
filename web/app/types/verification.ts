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
 * One location of an organisation, chosen in one go: "Albert Heijn · Breda" (validation_search_places). A location can
 * be run by other people than the rest of the organisation, so the request goes to someone there.
 */
export interface ValidationPlace {
  organizationId: string;
  organizationName: string;
  kind: ValidationOrganizationKind;
  // organizations.logo_url, only an https address.
  logoUrl: string | null;
  locationId: string;
  city: string;
  // "Westermarkt", when the organisation has more than one location in the city.
  locationName: string | null;
  // The street address, so the learner knows which location it is.
  address: string | null;
  // How many persons here may confirm this kind of evidence; 0 when nobody may any more.
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
  // The name of their location ("Westermarkt"), when it has one.
  locationName: string | null;
  organizationId: string;
  // Only for someone asked before, who may be of another organisation.
  organizationName: string | null;
}

/** A choice for the optional filters on persons (validation_contact_filters). */
export interface ValidationFilterOption {
  filter: 'location' | 'department' | 'function';
  value: string;
  label: string;
  // The location it belongs to (functions too, since migration 20261124150000).
  locationId: string | null;
  // How many persons it has.
  people: number;
}

/** Only narrow the persons at the chosen location; never sent. The department goes by name: "ICT" is one choice. */
export interface ValidationFilters {
  department: string;
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
  locationId: string | null;
  organisationName: string;
  requestedAt: string;
  response: string | null;
}
