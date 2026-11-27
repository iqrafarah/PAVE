import type {
  NotificationAudience,
  NotificationEntry,
  NotificationKind,
  NotificationSection,
  NotificationTab,
  PaveNotification,
} from '~/types/notifications';
import {
  NOTIFICATIONS_ACTION_NEEDED,
  NOTIFICATIONS_EARLIER,
  NOTIFICATIONS_MESSAGES,
  NOTIFICATIONS_THIS_WEEK,
  NOTIFICATIONS_TODAY,
} from './notificationMessages';

const DAY_MS = 24 * 60 * 60 * 1000;
/** How long a deleted notification can be brought back; the server purges it after that. */
export const RESTORABLE_DAYS = 7;

const KIND_ORDER: NotificationKind[] = ['verification_request', 'evidence_verified', 'evidence_rejected', 'conversation', 'email'];
const USUAL_KINDS: Record<NotificationAudience, NotificationKind[]> = {
  learner: ['conversation', 'evidence_verified', 'evidence_rejected'],
  administrator: ['conversation', 'verification_request'],
};

export interface NotificationFilter {
  tab: NotificationTab;
  searchText: string;
}

/** Which kinds a tab shows; Ayla's chats live in Ayla, so their meldingen stay under Alles (iOS NotificationTab.includes). */
export function tabIncludes(tab: NotificationTab, kind: NotificationKind) {
  switch (tab) {
    case 'all':
      return true;
    case 'conversations':
      return kind === 'email';
    case 'applications':
      return false;
    case 'evidence':
      return kind === 'evidence_verified' || kind === 'evidence_rejected' || kind === 'verification_request';
  }
}

/** Invitations from the fair are no meldingen of their own but a section above the list, under Alles and Werk. */
export function tabShowsApplications(tab: NotificationTab) {
  return tab === 'all' || tab === 'applications';
}

/** What the role normally gets, plus what is in the inbox: a reviewer still sees the decisions on their own evidence. */
export function availableKinds(audience: NotificationAudience, inbox: PaveNotification[]) {
  const present = new Set(inbox.map((notification) => notification.kind));
  return KIND_ORDER.filter((kind) => USUAL_KINDS[audience].includes(kind) || present.has(kind));
}

export function inboxOf(notifications: PaveNotification[]) {
  return notifications.filter((notification) => notification.deletedAt === null);
}

/** Not deleted and not read: what the bell shows. */
export function unreadCountOf(notifications: PaveNotification[]) {
  return notifications.filter((notification) => notification.deletedAt === null && notification.isUnread).length;
}

/** Who or what it is about, for the line under the title in the list and the banner (iOS PaveNotification.detail). */
export function notificationDetail(notification: PaveNotification) {
  switch (notification.kind) {
    case 'evidence_verified':
    case 'evidence_rejected':
      return [notification.documentName, notification.personName].filter(Boolean).join(' · ');
    case 'verification_request':
      return [notification.learnerName ?? notification.personName, notification.documentName].filter(Boolean).join(' · ');
    default:
      return notification.personName;
  }
}

/** "Ayla · 3 berichten" for a chat with several notifications, otherwise the detail. */
export function entrySubtitle(entry: NotificationEntry) {
  if (entry.notification.kind === 'conversation' && entry.ids.length > 1) {
    return `${entry.notification.personName} · ${NOTIFICATIONS_MESSAGES(entry.ids.length)}`;
  }
  return notificationDetail(entry.notification);
}

/** Every notification behind one row: all of the same chat in the inbox, or just the one. */
export function idsOf(notification: PaveNotification, inbox: PaveNotification[]) {
  const chat = notification.conversationId;
  if (notification.kind !== 'conversation' || !chat) return [notification.id];
  return inbox.filter((entry) => entry.kind === 'conversation' && entry.conversationId === chat).map((entry) => entry.id);
}

function matchesSearch(notification: PaveNotification, searchText: string) {
  const query = searchText.trim().toLocaleLowerCase('nl');
  if (!query) return true;
  const text = [notification.title, notification.personName, notification.learnerName, notification.documentName, notification.documentType]
    .filter(Boolean)
    .join(' ')
    .toLocaleLowerCase('nl');
  return text.includes(query);
}

/** Newest first, with Ayla's notifications of one chat folded into one row. */
export function applyNotificationFilter(inbox: PaveNotification[], kinds: NotificationKind[], filter: NotificationFilter) {
  const seenChats = new Set<string>();
  const entries: NotificationEntry[] = [];
  const matching = inbox
    .filter((notification) => kinds.includes(notification.kind))
    .filter((notification) => tabIncludes(filter.tab, notification.kind))
    .filter((notification) => matchesSearch(notification, filter.searchText))
    .sort((a, b) => b.date.localeCompare(a.date));
  for (const notification of matching) {
    const chat = notification.kind === 'conversation' ? notification.conversationId : null;
    if (chat) {
      if (seenChats.has(chat)) continue;
      seenChats.add(chat);
    }
    const ids = idsOf(notification, inbox);
    const isUnread = inbox.some((entry) => ids.includes(entry.id) && entry.isUnread);
    entries.push({ notification, ids, isUnread });
  }
  return entries;
}

function startOfDay(date: Date) {
  return new Date(date.getFullYear(), date.getMonth(), date.getDate()).getTime();
}

function daysAgo(isoDate: string, now: Date) {
  return Math.round((startOfDay(now) - startOfDay(new Date(isoDate))) / DAY_MS);
}

function sectionTitle(isoDate: string, now: Date) {
  const days = daysAgo(isoDate, now);
  if (days <= 0) return NOTIFICATIONS_TODAY;
  if (days <= 6) return NOTIFICATIONS_THIS_WEEK;
  return NOTIFICATIONS_EARLIER;
}

/**
 * Open verification requests first ("Actie nodig": the inbox only holds requests that are still pending), then
 * everything else by when it happened: Vandaag, Deze week and Eerder (iOS NotificationsScreen).
 */
export function groupEntries(entries: NotificationEntry[], now = new Date()): NotificationSection[] {
  const actionable = entries.filter((entry) => entry.notification.kind === 'verification_request');
  const rest = entries.filter((entry) => entry.notification.kind !== 'verification_request');
  const sections: NotificationSection[] = [];
  if (actionable.length) sections.push({ title: NOTIFICATIONS_ACTION_NEEDED, entries: actionable, needsAction: true });
  for (const title of [NOTIFICATIONS_TODAY, NOTIFICATIONS_THIS_WEEK, NOTIFICATIONS_EARLIER]) {
    const inSection = rest.filter((entry) => sectionTitle(entry.notification.date, now) === title);
    if (inSection.length) sections.push({ title, entries: inSection, needsAction: false });
  }
  return sections;
}

/** "Recent verwijderd": still restorable, newest deletion first. */
export function trashOf(notifications: PaveNotification[], now = Date.now()) {
  return notifications
    .filter((notification) => notification.deletedAt && daysLeft(notification.deletedAt, now) > 0)
    .sort((a, b) => (b.deletedAt ?? '').localeCompare(a.deletedAt ?? ''));
}

/** Whole days left to bring it back, at least 1 while it can still be restored. */
export function daysLeft(deletedAt: string, now = Date.now()) {
  const deadline = new Date(deletedAt).getTime() + RESTORABLE_DAYS * DAY_MS;
  if (deadline <= now) return 0;
  return Math.max(1, Math.ceil((deadline - now) / DAY_MS));
}

/** The time today, "gisteren", the weekday this week, otherwise the date (iOS NotificationInboxRow.when). */
export function notificationTime(isoDate: string, now = new Date()) {
  const date = new Date(isoDate);
  const days = daysAgo(isoDate, now);
  if (days <= 0) return date.toLocaleTimeString('nl-NL', { hour: '2-digit', minute: '2-digit' });
  if (days === 1) return 'gisteren';
  if (days <= 6) return date.toLocaleDateString('nl-NL', { weekday: 'short' });
  return date.toLocaleDateString('nl-NL', { day: 'numeric', month: 'short' });
}
