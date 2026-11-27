import type { RealtimeChannel } from '@supabase/supabase-js';
import type {
  NotificationAudience,
  NotificationKind,
  PaveNotification,
  ReviewFile,
  ReviewItem,
  ReviewOutcome,
  ReviewPayload,
  ReviewRequest,
} from '~/types/notifications';

export type NotificationsStatus = 'idle' | 'loading' | 'ready' | 'failed';

interface NotificationsState {
  status: NotificationsStatus;
  audience: NotificationAudience;
  notifications: PaveNotification[];
  loadError: string | null;
  // A notification that arrived while PAVE was open: a small banner until it is dismissed or opened.
  banner: PaveNotification | null;
  // The chat on screen: a notification about it needs no banner, and is read at once.
  openConversationId: string | null;
}

interface InboxRow {
  id: string;
  kind: string;
  title: string;
  personName: string;
  date: string;
  isUnread: boolean;
  deletedAt: string | null;
  conversationID?: string;
  validationRequestID?: string;
  vaultItemID?: string;
  learnerName?: string;
  learnerOrganization?: string;
  documentName?: string;
  documentType?: string;
}

interface InboxResponse {
  audience: string;
  notifications: InboxRow[];
}

/** The vault_items row as it is in the database, with the skills and signed files added by vault-review. */
interface ReviewItemRow {
  id: string;
  title: string;
  category: string;
  description: string | null;
  organisation_name: string | null;
  organisation_location: string | null;
  start_date: string | null;
  end_date: string | null;
  issued_on: string | null;
  is_current: boolean;
  skills: string[];
  files: ReviewFile[];
}

interface ReviewResponse {
  request: ReviewRequest;
  item: ReviewItemRow;
}

// As on iOS: the inbox is read again every 30 seconds while PAVE is on screen, and an open chat is announced every 20.
const POLL_MS = 30_000;
const OPEN_CHAT_MS = 20_000;
const DEVICE_KEY = 'pave-open-chat-device';

function toReviewItem(row: ReviewItemRow): ReviewItem {
  return {
    id: row.id,
    title: row.title,
    category: row.category,
    description: row.description,
    organisationName: row.organisation_name,
    organisationLocation: row.organisation_location,
    startDate: row.start_date,
    endDate: row.end_date,
    issuedOn: row.issued_on,
    isCurrent: row.is_current,
    skills: row.skills ?? [],
    files: row.files ?? [],
  };
}

const KNOWN_KINDS: NotificationKind[] = ['conversation', 'evidence_verified', 'evidence_rejected', 'verification_request'];

function toNotification(row: InboxRow): PaveNotification | null {
  const kind = KNOWN_KINDS.find((known) => known === row.kind);
  if (!kind) return null;
  return {
    id: row.id,
    kind,
    title: row.title,
    personName: row.personName,
    date: row.date,
    isUnread: row.isUnread,
    deletedAt: row.deletedAt ?? null,
    conversationId: row.conversationID ?? null,
    validationRequestId: row.validationRequestID ?? null,
    vaultItemId: row.vaultItemID ?? null,
    learnerName: row.learnerName ?? null,
    learnerOrganization: row.learnerOrganization ?? null,
    documentName: row.documentName ?? null,
    documentType: row.documentType ?? null,
  };
}

/** This browser, so a phone and a browser of the same account never take each other's open chat (iOS keepOpen). */
function deviceId() {
  try {
    const kept = localStorage.getItem(DEVICE_KEY);
    if (kept) return kept;
    const id = `web-${crypto.randomUUID()}`;
    localStorage.setItem(DEVICE_KEY, id);
    return id;
  } catch {
    return `web-${Math.random().toString(36).slice(2)}`;
  }
}

// Kept outside the reactive state: ids seen so far (null before the first load, so opening PAVE does not announce
// the whole inbox), the timers, and the last save per notification.
let knownIds: Set<string> | null = null;
let pollTimer: ReturnType<typeof setInterval> | undefined;
let channel: RealtimeChannel | null = null;
let isRunning = false;
const pendingChanges = new Map<string, Promise<unknown>>();

/**
 * The inbox (iOS NotificationsModel): read through vault-review, which only shows what you may see. Marking as read and
 * (soft) deleting go straight to user_notifications; the database only allows those two changes. One shared state for
 * the bell, the banner and the Meldingen page.
 */
export function useNotifications() {
  const supabase = useUntypedSupabase();
  const { call } = useVaultReview();
  const alerts = useNotificationAlerts();
  const state = useState<NotificationsState>('pave-notifications', () => ({
    status: 'idle',
    audience: 'learner',
    notifications: [],
    loadError: null,
    banner: null,
    openConversationId: null,
  }));

  const unreadCount = computed(() => unreadCountOf(state.value.notifications));

  /** Only while the chat is really in view: in a hidden tab you would miss it. */
  function isAboutOpenChat(notification: PaveNotification) {
    const open = state.value.openConversationId;
    if (!open || document.visibilityState !== 'visible') return false;
    return notification.kind === 'conversation' && notification.conversationId === open;
  }

  /**
   * What counts as new: unread, not deleted and not seen on an earlier load. About the chat on screen: no banner, and
   * read at once. Otherwise the newest becomes the banner, and a browser notification when PAVE is not in view.
   */
  function announceArrivals(rows: PaveNotification[]) {
    const ids = new Set(rows.map((row) => row.id));
    const previous = knownIds;
    knownIds = ids;
    if (!previous) return;
    const arrived = rows.filter((row) => !previous.has(row.id) && row.isUnread && row.deletedAt === null);
    const inOpenChat = arrived.filter(isAboutOpenChat);
    if (inOpenChat.length) markRead(inOpenChat.map((row) => row.id));
    const fresh = arrived.filter((row) => !isAboutOpenChat(row)).sort((a, b) => b.date.localeCompare(a.date));
    const newest = fresh[0];
    if (!newest) return;
    state.value.banner = newest;
    alerts.show(newest);
  }

  async function load() {
    if (state.value.status !== 'ready') state.value.status = 'loading';
    const { data, errorCode } = await call<InboxResponse>('inbox');
    if (!data) {
      state.value.loadError = functionErrorMessage(errorCode, NOTIFICATIONS_LOAD_FAILED);
      if (state.value.status !== 'ready') state.value.status = 'failed';
      return;
    }
    const rows = data.notifications.map(toNotification).filter((notification): notification is PaveNotification => notification !== null);
    state.value.audience = data.audience === 'administrator' ? 'administrator' : 'learner';
    state.value.notifications = rows;
    state.value.loadError = null;
    state.value.status = 'ready';
    announceArrivals(rows);
  }

  function replace(ids: string[], changes: Partial<PaveNotification>) {
    state.value.notifications = state.value.notifications.map((notification) =>
      ids.includes(notification.id) ? { ...notification, ...changes } : notification,
    );
  }

  /** Shows them as read at once; once read, the database keeps the first time. */
  async function markRead(ids: string[]) {
    if (!ids.length) return;
    replace(ids, { isUnread: false });
    if (state.value.banner && ids.includes(state.value.banner.id)) state.value.banner = null;
    await supabase.from('user_notifications').update({ read_at: new Date().toISOString() }).in('id', ids).is('read_at', null);
  }

  /** Everything unread in the inbox at once; row-level security keeps it to your own notifications (as on iOS). */
  async function markAllRead() {
    state.value.notifications = state.value.notifications.map((entry) => ({ ...entry, isUnread: false }));
    state.value.banner = null;
    await supabase
      .from('user_notifications')
      .update({ read_at: new Date().toISOString() })
      .is('read_at', null)
      .is('deleted_at', null);
  }

  /** One save after the other per notification, so a quick "Ongedaan maken" never reaches the server before the delete. */
  function saveDeleted(id: string, isDeleted: boolean) {
    const earlier = pendingChanges.get(id) ?? Promise.resolve();
    const change = earlier.then(async () => {
      const { data, error } = await supabase
        .from('user_notifications')
        .update({ deleted_at: isDeleted ? new Date().toISOString() : null })
        .eq('id', id)
        .select('id');
      return !error && Boolean(data?.length);
    });
    pendingChanges.set(id, change);
    void change.finally(() => {
      if (pendingChanges.get(id) === change) pendingChanges.delete(id);
    });
    return change;
  }

  /**
   * Moves them to "Recent verwijderd" (or back) at once. Each one the server refuses comes back as it was, unless it was
   * changed again in the meantime. The database sets the real time of deleting.
   */
  async function setDeleted(ids: string[], isDeleted: boolean) {
    const previous = new Map(state.value.notifications.filter((entry) => ids.includes(entry.id)).map((entry) => [entry.id, entry.deletedAt]));
    replace(ids, { deletedAt: isDeleted ? new Date().toISOString() : null });
    if (isDeleted && state.value.banner && ids.includes(state.value.banner.id)) state.value.banner = null;
    const results = await Promise.all(ids.map((id) => saveDeleted(id, isDeleted)));
    const failed = ids.filter((_, index) => !results[index]);
    for (const id of failed) {
      const current = state.value.notifications.find((entry) => entry.id === id);
      if (current && (current.deletedAt !== null) === isDeleted) replace([id], { deletedAt: previous.get(id) ?? null });
    }
    return { isFailed: failed.length > 0 };
  }

  async function loadReview(requestId: string) {
    const { data, errorCode } = await call<ReviewResponse>('detail', { requestId });
    if (!data) return { data: null, error: functionErrorMessage(errorCode, REVIEW_LOAD_FAILED) };
    const payload: ReviewPayload = { request: data.request, item: toReviewItem(data.item) };
    return { data: payload, error: null };
  }

  /** Null when the decision is saved; otherwise what went wrong, for the reviewer. */
  async function resolve(requestId: string, outcome: ReviewOutcome, response: string | null) {
    const { errorCode } = await call('resolve', { requestId, outcome, response: response ?? '' });
    if (errorCode) return functionErrorMessage(errorCode, REVIEW_DECISION_FAILED);
    await load();
    return null;
  }

  function dismissBanner() {
    state.value.banner = null;
  }

  function setOpenConversation(id: string | null) {
    state.value.openConversationId = id;
    const banner = state.value.banner;
    if (id && banner?.kind === 'conversation' && banner.conversationId === id) state.value.banner = null;
  }

  /**
   * Tells the database this chat is on screen, every 20 seconds until the returned function is called, and then lets go
   * of it. While it is open, Ayla's answers in it give no notification (migration 20261125120000). Fails quietly.
   */
  function keepOpen(conversationId: string) {
    const device = deviceId();
    const announce = (isOpen: boolean) =>
      supabase.rpc('set_open_chat', { p_device: device, p_conversation_id: conversationId, p_open: isOpen }).then(
        () => {},
        () => {},
      );
    setOpenConversation(conversationId);
    announce(true);
    const timer = setInterval(() => {
      if (document.visibilityState === 'visible') announce(true);
    }, OPEN_CHAT_MS);
    return () => {
      clearInterval(timer);
      if (state.value.openConversationId === conversationId) setOpenConversation(null);
      announce(false);
    };
  }

  function handleVisibility() {
    if (document.visibilityState === 'visible') load();
  }

  /**
   * Keeps the inbox fresh while signed in (iOS MainView): read now, every 30 seconds while the page is in view, at once
   * when a new row arrives (Realtime) and when you come back to the tab.
   */
  async function start() {
    if (isRunning || !import.meta.client) return;
    isRunning = true;
    load();
    pollTimer = setInterval(() => {
      // Hidden tabs keep polling, so a browser notification can still reach you; just less eagerly.
      if (document.visibilityState === 'visible' || alerts.isEnabled.value) load();
    }, POLL_MS);
    document.addEventListener('visibilitychange', handleVisibility);
    const { data } = await supabase.auth.getUser();
    const userId = data.user?.id;
    if (!userId || !isRunning) return;
    channel = supabase
      .channel(`user-notifications-${userId}`)
      .on('postgres_changes', { event: 'INSERT', schema: 'public', table: 'user_notifications', filter: `recipient_id=eq.${userId}` }, () => load())
      .subscribe();
  }

  /** Signed out: nothing keeps running, and the next account starts with an empty inbox. */
  function stop() {
    isRunning = false;
    clearInterval(pollTimer);
    if (import.meta.client) document.removeEventListener('visibilitychange', handleVisibility);
    if (channel) supabase.removeChannel(channel);
    channel = null;
    knownIds = null;
    state.value = { status: 'idle', audience: 'learner', notifications: [], loadError: null, banner: null, openConversationId: null };
  }

  return {
    state,
    unreadCount,
    load,
    markRead,
    markAllRead,
    setDeleted,
    loadReview,
    resolve,
    dismissBanner,
    keepOpen,
    start,
    stop,
  };
}
