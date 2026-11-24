import type { RealtimeChannel } from '@supabase/supabase-js';
import type { AylaDevice, Conversation } from '~/types/ayla';

export type ChatsStatus = 'idle' | 'loading' | 'ready' | 'failed';

interface ChatsState {
  conversations: Conversation[];
  status: ChatsStatus;
  canPin: boolean;
  canArchive: boolean;
  // False until ayla_conversations.expiry_days exists (migration 20261120120000): no Verval per chat yet.
  canExpire: boolean;
  hiddenIds: string[];
}

interface ConversationRow {
  id: string;
  title: string | null;
  updated_at: string;
  created_at?: string | null;
  pinned_at?: string | null;
  archived_at?: string | null;
  expiry_days?: number | null;
  started_on: AylaDevice;
}

const LIST_LIMIT = 50;
const SEARCH_LIMIT = 30;
const COLUMNS_WITH_EXPIRY = 'id,title,created_at,updated_at,pinned_at,archived_at,expiry_days,started_on';
const COLUMNS_WITH_ARCHIVE = 'id,title,created_at,updated_at,pinned_at,archived_at,started_on';
// Chats whose time is up are deleted on the server when the list loads, at most every ten minutes (as on iOS).
const EXPIRY_CHECK_MS = 10 * 60 * 1000;
let lastExpiryCheck = 0;
const COLUMNS_WITH_PIN = 'id,title,updated_at,pinned_at,started_on';
const COLUMNS_WITHOUT_PIN = 'id,title,updated_at,started_on';
const LIKE_SPECIAL_CHARACTERS = /[\\%_]/g;

function toConversation(row: ConversationRow): Conversation {
  return {
    id: row.id,
    title: row.title || AYLA_NEW_CONVERSATION_TITLE,
    updatedAt: row.updated_at,
    pinnedAt: row.pinned_at ?? null,
    archivedAt: row.archived_at ?? null,
    createdAt: row.created_at ?? null,
    expiryDays: row.expiry_days ?? null,
    startedOn: row.started_on,
  };
}

function sortForList(conversations: Conversation[]) {
  return [...conversations].sort((first, second) => second.updatedAt.localeCompare(first.updatedAt));
}

/** The user's conversations with Ayla (docs/ayla.md, section 4). */
export function useAylaChats() {
  const openMenu = useAylaOpenMenu();
  const supabase = useUntypedSupabase();
  const signedIn = useSupabaseUser();
  const state = useState<ChatsState>('ayla-chats', () => ({
    conversations: [],
    status: 'idle',
    canPin: true,
    canArchive: true,
    canExpire: true,
    hiddenIds: [],
  }));

  const lock = useAylaChatLock();

  // Locked chats stay out of the list and the search until the PIN is entered on the locked chats page.
  const visibleConversations = computed(() =>
    state.value.conversations.filter(
      (conversation) =>
        !state.value.hiddenIds.includes(conversation.id) && !lock.isLocked(conversation.id) && !conversation.archivedAt,
    ),
  );

  // Archived chats are kept apart, under "Gearchiveerd". A locked chat stays hidden behind its PIN.
  const archivedConversations = computed(() =>
    state.value.conversations
      .filter(
        (conversation) =>
          conversation.archivedAt && !state.value.hiddenIds.includes(conversation.id) && !lock.isLocked(conversation.id),
      )
      .sort((first, second) => (second.archivedAt ?? '').localeCompare(first.archivedAt ?? '')),
  );

  function selectConversations(columns: string) {
    return supabase
      .from('ayla_conversations')
      .select(columns)
      .order('updated_at', { ascending: false })
      .limit(LIST_LIMIT);
  }

  async function load() {
    if (openMenu.openCount.value > 0) {
      openMenu.hasPendingReload.value = true;
      return;
    }
    // After a refresh the chats show at once as they were, and are checked against the database right after.
    if (state.value.status !== 'ready') {
      const kept = readKept<{ conversations: Conversation[]; canPin: boolean }>('chats', signedIn.value?.sub);
      if (kept) Object.assign(state.value, { conversations: kept.conversations, canPin: kept.canPin, status: 'ready' });
    }
    if (state.value.status !== 'ready') state.value.status = 'loading';

    await expireChats();
    let { data, error } = await selectConversations(COLUMNS_WITH_EXPIRY);
    // Until the expiry_days migration runs there is no Verval per chat; the archive may already be there.
    state.value.canExpire = true;
    state.value.canArchive = true;
    if (isMissingColumn(error)) {
      state.value.canExpire = false;
      ({ data, error } = await selectConversations(COLUMNS_WITH_ARCHIVE));
    }
    // Until the archived_at migration runs, archiving is hidden and the list still loads.
    if (isMissingColumn(error)) {
      state.value.canArchive = false;
      ({ data, error } = await selectConversations(COLUMNS_WITH_PIN));
    }
    // Until the pinned_at migration runs, pinning is hidden and the list still loads.
    if (isMissingColumn(error)) {
      state.value.canPin = false;
      ({ data, error } = await selectConversations(COLUMNS_WITHOUT_PIN));
    }
    if (error || !data) {
      state.value.status = 'failed';
      return;
    }
    const rows = data as unknown as ConversationRow[];
    // The archive in full, also chats older than the most recent ones (as on iOS).
    if (state.value.canArchive) {
      const archived = await supabase
        .from('ayla_conversations')
        .select(state.value.canExpire ? COLUMNS_WITH_EXPIRY : COLUMNS_WITH_ARCHIVE)
        .not('archived_at', 'is', null)
        .order('archived_at', { ascending: false });
      const known = new Set(rows.map((row) => row.id));
      for (const row of (archived.data ?? []) as unknown as ConversationRow[]) if (!known.has(row.id)) rows.push(row);
    }
    state.value.conversations = rows.map(toConversation);
    state.value.status = 'ready';
  }

  /** Deletes the chats of this account whose time is up (ayla_expire_my_chats); missing before its migration. */
  async function expireChats() {
    if (Date.now() - lastExpiryCheck < EXPIRY_CHECK_MS) return;
    lastExpiryCheck = Date.now();
    await supabase.rpc('ayla_expire_my_chats');
  }

  async function subscribe(): Promise<RealtimeChannel | null> {
    const { data } = await supabase.auth.getUser();
    const userId = data.user?.id;
    if (!userId) return null;

    return supabase
      .channel(`ayla-conversations-${userId}`)
      .on(
        'postgres_changes',
        { event: '*', schema: 'public', table: 'ayla_conversations', filter: `user_id=eq.${userId}` },
        () => load(),
      )
      .subscribe();
  }

  function unsubscribe(channel: RealtimeChannel | null) {
    if (channel) supabase.removeChannel(channel);
  }

  function replaceConversation(id: string, changes: Partial<Conversation>) {
    state.value.conversations = sortForList(
      state.value.conversations.map((conversation) =>
        conversation.id === id ? { ...conversation, ...changes } : conversation,
      ),
    );
  }

  function findConversation(id: string) {
    return state.value.conversations.find((conversation) => conversation.id === id);
  }

  /** Changes the list first and puts it back when Supabase refuses: an empty result means a rule said no. */
  async function updateConversation(id: string, changes: Partial<Conversation>, columns: Record<string, unknown>) {
    const previous = findConversation(id);
    if (!previous) return { isFailed: true };

    replaceConversation(id, changes);
    const { data, error } = await supabase.from('ayla_conversations').update(columns).eq('id', id).select('id');
    const isFailed = Boolean(error) || !data?.length;
    if (isFailed) replaceConversation(id, previous);
    return { isFailed };
  }

  function setPinned(id: string, isPinned: boolean) {
    const pinnedAt = isPinned ? new Date().toISOString() : null;
    return updateConversation(id, { pinnedAt }, { pinned_at: pinnedAt });
  }

  /** An archived chat is no longer pinned, so it comes back as an ordinary chat (as on iOS). */
  function setArchived(id: string, isArchived: boolean) {
    const archivedAt = isArchived ? new Date().toISOString() : null;
    if (!isArchived) return updateConversation(id, { archivedAt }, { archived_at: archivedAt });
    return updateConversation(id, { archivedAt, pinnedAt: null }, { archived_at: archivedAt, pinned_at: null });
  }

  /** "Verval" of one chat: null follows the account, 0 never expires, otherwise after that many days. */
  function setExpiry(id: string, expiryDays: number | null) {
    return updateConversation(id, { expiryDays }, { expiry_days: expiryDays });
  }

  function rename(id: string, title: string) {
    const trimmedTitle = title.trim().replace(/\s+/g, ' ').slice(0, AYLA_MAX_TITLE_LENGTH);
    if (!trimmedTitle) return Promise.resolve({ isFailed: true });
    return updateConversation(id, { title: trimmedTitle }, { title: trimmedTitle });
  }

  /** Hides a chat right away; `deleteHidden` removes it for good after the undo time. */
  function hide(id: string) {
    state.value.hiddenIds = [...state.value.hiddenIds, id];
  }

  function unhide(id: string) {
    state.value.hiddenIds = state.value.hiddenIds.filter((hiddenId) => hiddenId !== id);
  }

  async function deleteHidden(id: string) {
    const { data, error } = await supabase.from('ayla_conversations').delete().eq('id', id).select('id');
    const isFailed = Boolean(error) || !data?.length;
    if (!isFailed) {
      state.value.conversations = state.value.conversations.filter((conversation) => conversation.id !== id);
      // Its files kept on this device go with it.
      forgetChatFiles(id);
    }
    unhide(id);
    return { isFailed };
  }

  /** The ids of conversations with a message that contains the words (from 2 characters). */
  async function searchMessages(words: string) {
    const pattern = `%${words.trim().replace(LIKE_SPECIAL_CHARACTERS, '\\$&')}%`;
    const { data, error } = await supabase
      .from('ayla_messages')
      .select('id,conversation_id,text')
      .ilike('text', pattern)
      .order('created_at', { ascending: false })
      .limit(SEARCH_LIMIT);
    if (error || !data) return { conversationIds: [], snippets: {} as Record<string, string>, isFailed: true };

    const rows = data as { conversation_id: string; text: string }[];
    const visible = rows.filter((row) => !lock.isLocked(row.conversation_id));
    const needle = words.trim().toLocaleLowerCase('nl');
    // A short piece of the newest message that holds the words, with a little around it, for the search results.
    const snippets: Record<string, string> = {};
    for (const row of visible) {
      if (snippets[row.conversation_id]) continue;
      const text = row.text.replace(/\s+/g, ' ');
      const at = Math.max(0, text.toLocaleLowerCase('nl').indexOf(needle));
      const start = Math.max(0, at - 40);
      snippets[row.conversation_id] = `${start > 0 ? '… ' : ''}${text.slice(start, start + 140)}${start + 140 < text.length ? ' …' : ''}`;
    }
    return { conversationIds: Object.keys(snippets), snippets, isFailed: false };
  }

  return {
    state,
    visibleConversations,
    archivedConversations,
    load,
    subscribe,
    unsubscribe,
    setPinned,
    setArchived,
    setExpiry,
    rename,
    hide,
    unhide,
    deleteHidden,
    searchMessages,
  };
}
