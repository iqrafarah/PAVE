import type { EmailAccount, EmailAddress, EmailMessage, EmailMessageBody, EmailOverview, EmailRef, EmailThread } from '#shared/types/email';

// The connected mailbox and its conversations, for Meldingen (iOS EmailModel). The web server logs in at iCloud for
// the learner (server/api/email); the mail itself is only kept in this tab, nothing of it is stored.

/** How often the list looks for new mail while PAVE is open and visible (iOS waits with IMAP IDLE). */
const REFRESH_MS = 2 * 60 * 1000;
/** How long "Ongedaan maken" stays before a deleted conversation really goes to the bin. */
export const EMAIL_UNDO_MS = 5000;

type EmailStatus = 'idle' | 'loading' | 'ready' | 'failed';

interface EmailState {
  status: EmailStatus;
  /** False when this server has no e-mail set up (no key): then Meldingen does not offer it. */
  isAvailable: boolean;
  account: EmailAccount | null;
  threads: EmailThread[];
  people: EmailAddress[];
  problem: string | null;
  /** Text and files of opened messages, by message id, so a refresh does not throw them away. */
  bodies: Record<string, EmailMessageBody>;
  /** Conversations just deleted, hidden while "Ongedaan maken" is on screen. */
  hiddenIds: string[];
}

let refreshTimer: ReturnType<typeof setInterval> | undefined;
let loading: Promise<void> | null = null;
const deleteTimers = new Map<string, ReturnType<typeof setTimeout>>();

function refsOf(messages: EmailMessage[]): EmailRef[] {
  return messages.map((message) => message.ref);
}

export function useEmail() {
  const state = useState<EmailState>('pave-email', () => ({
    status: 'idle',
    isAvailable: true,
    account: null,
    threads: [],
    people: [],
    problem: null,
    bodies: {},
    hiddenIds: [],
  }));

  const threads = computed(() => state.value.threads.filter((thread) => !state.value.hiddenIds.includes(thread.id)));
  const unreadCount = computed(() => threads.value.filter(isThreadUnread).length);
  const hasAccount = computed(() => state.value.account !== null);

  function threadById(id: string) {
    return threads.value.find((thread) => thread.id === id) ?? null;
  }

  async function fetchOverview() {
    try {
      const overview = await $fetch<EmailOverview>('/api/email');
      state.value.account = overview.account;
      state.value.threads = overview.threads;
      state.value.people = overview.people;
      state.value.problem = null;
      state.value.isAvailable = true;
      state.value.status = 'ready';
    } catch (error) {
      // Without the table or the key (not set up yet) e-mail simply is not there.
      const code = emailErrorCode(error);
      if (code === 'not_configured' || code === 'not_signed_in') {
        state.value.isAvailable = code !== 'not_configured';
        state.value.account = null;
        state.value.threads = [];
        state.value.status = 'ready';
        return;
      }
      state.value.problem = emailErrorMessage(error, EMAIL_ERRORS.network);
      state.value.status = state.value.status === 'ready' ? 'ready' : 'failed';
    }
  }

  /** One load at a time: a refresh that comes while one is running waits for that one. */
  function load() {
    if (!loading) {
      if (state.value.status !== 'ready') state.value.status = 'loading';
      loading = fetchOverview().finally(() => (loading = null));
    }
    return loading;
  }

  async function connect(address: string, password: string) {
    try {
      state.value.account = await $fetch<EmailAccount>('/api/email/account', { method: 'POST', body: { address, password } });
      await load();
      return { error: null };
    } catch (error) {
      return { error: emailErrorMessage(error, EMAIL_ERRORS.server) };
    }
  }

  async function disconnect() {
    try {
      await $fetch('/api/email/account', { method: 'DELETE' });
      state.value.account = null;
      state.value.threads = [];
      state.value.people = [];
      state.value.bodies = {};
      state.value.problem = null;
      return { error: null };
    } catch (error) {
      return { error: emailErrorMessage(error, EMAIL_ERRORS.server) };
    }
  }

  /** The text and files of a conversation's messages that are not here yet. */
  async function loadBodies(thread: EmailThread) {
    const missing = thread.messages.filter((message) => !state.value.bodies[message.id]);
    if (!missing.length) return { error: null };
    try {
      const bodies = await $fetch<EmailMessageBody[]>('/api/email/messages', { method: 'POST', body: { refs: refsOf(missing) } });
      const next = { ...state.value.bodies };
      for (const body of bodies) next[body.id] = body;
      state.value.bodies = next;
      return { error: null };
    } catch (error) {
      return { error: emailErrorMessage(error, EMAIL_ERRORS.network) };
    }
  }

  function setRead(threadId: string) {
    state.value.threads = state.value.threads.map((thread) =>
      thread.id === threadId ? { ...thread, messages: thread.messages.map((message) => ({ ...message, isRead: true })) } : thread,
    );
  }

  /** Read here at once, and in the mailbox too, so Mail on the Mac agrees. */
  async function markRead(threadId: string) {
    const thread = threadById(threadId);
    const unread = thread?.messages.filter((message) => !message.isRead) ?? [];
    if (!unread.length) return;
    setRead(threadId);
    await $fetch('/api/email/read', { method: 'POST', body: { refs: refsOf(unread) } }).catch(() => load());
  }

  /** Hides the conversation at once and moves it to the bin once "Ongedaan maken" is gone. */
  function deleteThread(threadId: string, onFailed: () => void) {
    const thread = threadById(threadId);
    if (!thread) return;
    state.value.hiddenIds = [...state.value.hiddenIds, threadId];
    clearTimeout(deleteTimers.get(threadId));
    deleteTimers.set(
      threadId,
      setTimeout(async () => {
        deleteTimers.delete(threadId);
        try {
          await $fetch('/api/email/trash', { method: 'POST', body: { refs: refsOf(thread.messages) } });
          state.value.threads = state.value.threads.filter((entry) => entry.id !== threadId);
        } catch {
          onFailed();
        } finally {
          state.value.hiddenIds = state.value.hiddenIds.filter((id) => id !== threadId);
        }
      }, EMAIL_UNDO_MS),
    );
  }

  function undoDelete(threadId: string) {
    clearTimeout(deleteTimers.get(threadId));
    deleteTimers.delete(threadId);
    state.value.hiddenIds = state.value.hiddenIds.filter((id) => id !== threadId);
  }

  /**
   * Sends a new message or a reply, then reads the list again: the server has put the copy in Verzonden by then.
   * Returns the conversation it ended up in.
   */
  async function send(mail: {
    to: EmailAddress[];
    cc: EmailAddress[];
    subject: string;
    text: string;
    files: File[];
    replyTo: EmailMessage | null;
  }) {
    const form = new FormData();
    const replyTo = mail.replyTo;
    form.append(
      'mail',
      JSON.stringify({
        to: mail.to,
        cc: mail.cc,
        subject: mail.subject,
        text: mail.text,
        inReplyTo: replyTo?.messageId ?? null,
        references: replyTo ? [...replyTo.references, ...(replyTo.messageId ? [replyTo.messageId] : [])] : [],
      }),
    );
    for (const file of mail.files) form.append('file', file, file.name);
    try {
      const sent = await $fetch<{ messageId: string }>('/api/email/send', { method: 'POST', body: form });
      await load();
      const id = sent.messageId.replace(/^<|>$/g, '').toLowerCase();
      const thread = state.value.threads.find((entry) =>
        entry.messages.some((message) => message.messageId?.replace(/^<|>$/g, '').toLowerCase() === id),
      );
      return { error: null, threadId: thread?.id ?? null };
    } catch (error) {
      return { error: emailErrorMessage(error, ''), threadId: null };
    }
  }

  function attachmentUrl(message: EmailMessage, index: number) {
    const query = new URLSearchParams({ folder: message.ref.folder, uid: String(message.ref.uid), index: String(index) });
    return `/api/email/attachment?${query}`;
  }

  function refreshWhenVisible() {
    if (document.visibilityState === 'visible' && state.value.account) load();
  }

  /** Keeps the list fresh while signed in, so the bell counts new mail too. */
  function start() {
    if (refreshTimer) return;
    load();
    refreshTimer = setInterval(refreshWhenVisible, REFRESH_MS);
    document.addEventListener('visibilitychange', refreshWhenVisible);
  }

  function stop() {
    clearInterval(refreshTimer);
    refreshTimer = undefined;
    document.removeEventListener('visibilitychange', refreshWhenVisible);
    state.value = { status: 'idle', isAvailable: true, account: null, threads: [], people: [], problem: null, bodies: {}, hiddenIds: [] };
  }

  return {
    state,
    threads,
    unreadCount,
    hasAccount,
    threadById,
    load,
    connect,
    disconnect,
    loadBodies,
    markRead,
    deleteThread,
    undoDelete,
    send,
    attachmentUrl,
    start,
    stop,
  };
}
