/** The kinds in user_notifications.kind (docs/verificatie.md), and `email`: a conversation of the connected mailbox. */
export type NotificationKind = 'conversation' | 'evidence_verified' | 'evidence_rejected' | 'verification_request' | 'email';

/** A reviewer ("administrator") is the account behind at least one organization_contacts row; everyone else is a learner. */
export type NotificationAudience = 'learner' | 'administrator';

/** One row of the inbox, as the vault-review Edge Function sends it (action "inbox"). */
export interface PaveNotification {
  id: string;
  kind: NotificationKind;
  title: string;
  personName: string;
  date: string;
  isUnread: boolean;
  deletedAt: string | null;
  conversationId: string | null;
  validationRequestId: string | null;
  vaultItemId: string | null;
  // Only on a verification request: who asked, and at which organisation.
  learnerName: string | null;
  learnerOrganization: string | null;
  documentName: string | null;
  documentType: string | null;
  // Only on an e-mail conversation (kind `email`): its id in the mailbox.
  emailThreadId?: string;
}

/**
 * One row of the list: a notification, or all of Ayla's notifications of one chat folded together (iOS NotificationsScreen),
 * the newest on top. `ids` are all the notifications behind it, so reading or deleting the row does all of them.
 */
export interface NotificationEntry {
  notification: PaveNotification;
  ids: string[];
  isUnread: boolean;
}

export type NotificationTab = 'all' | 'unread';

/** "Actie nodig" first (open verification requests), then Vandaag, Deze week and Eerder. */
export interface NotificationSection {
  title: string;
  entries: NotificationEntry[];
  needsAction: boolean;
}

/** A file of the evidence under review, with a link that works for five minutes. */
export interface ReviewFile {
  id: string;
  name: string;
  mimeType: string;
  role: 'document' | 'cover' | 'logo';
  url: string;
}

/** The evidence a reviewer is asked to confirm (action "detail"). Dates are `YYYY-MM-DD`. */
export interface ReviewItem {
  id: string;
  title: string;
  category: string;
  description: string | null;
  organisationName: string | null;
  organisationLocation: string | null;
  startDate: string | null;
  endDate: string | null;
  issuedOn: string | null;
  isCurrent: boolean;
  skills: string[];
  files: ReviewFile[];
}

export interface ReviewRequest {
  id: string;
  requestedAt: string;
  message: string | null;
  learnerName: string;
}

export interface ReviewPayload {
  request: ReviewRequest;
  item: ReviewItem;
}

export type ReviewOutcome = 'verified' | 'rejected';
