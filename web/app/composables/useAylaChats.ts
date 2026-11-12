import type { RealtimeChannel } from '@supabase/supabase-js';
import type { AylaDevice, Conversation } from '~/types/ayla';

export type ChatsStatus = 'idle' | 'loading' | 'ready' | 'failed';

interface ChatsState {
  conversations: Conversation[];
  status: ChatsStatus;
  canPin: boolean;
  hiddenIds: string[];
}

interface ConversationRow {
  id: string;
  title: string | null;
  updated_at: string;
  pinned_at?: string | null;
  started_on: AylaDevice;
}

const LIST_LIMIT = 50;
const SEARCH_LIMIT = 30;
const COLUMNS_WITH_PIN = 'id,title,updated_at,pinned_at,started_on';
const COLUMNS_WITHOUT_PIN = 'id,title,updated_at,started_on';
const LIKE_SPECIAL_CHARACTERS = /[\\%_]/g;

function toConversation(row: ConversationRow): Conversation {
  return {
    id: row.id,
    title: row.title || AYLA_NEW_CONVERSATION_TITLE,
    updatedAt: row.updated_at,
    pinnedAt: row.pinned_at ?? null,
    startedOn: row.started_on,
  };
}

function sortForList(conversations: Conversation[]) {
  return [...conversations].sort((first, second) => second.updatedAt.localeCompare(first.updatedAt));
}

/** The user's conversations with Ayla (docs/ayla.md, section 4). */
export function useAylaChats() {
  const supabase = useUntypedSupabase();
  const state = useState<ChatsState>('ayla-chats', () => ({
    conversations: [],
    status: 'idle',
    canPin: true,
    hiddenIds: [],
  }));

  const visibleConversations = computed(() =>
    state.value.conversations.filter((conversation) => !state.value.hiddenIds.includes(conversation.id)),
  );

  function selectConversations(columns: string) {
    return supabase
      .from('ayla_conversations')
      .select(columns)
      .order('updated_at', { ascending: false })
      .limit(LIST_LIMIT);
  }

  async function load() {
    if (state.value.status !== 'ready') state.value.status = 'loading';

    let { data, error } = await selectConversations(COLUMNS_WITH_PIN);
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
    state.value.conversations = rows.map(toConversation);
    state.value.status = 'ready';
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

  function rename(id: string, title: string) {
    const trimmedTitle = title.trim();
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
    if (error || !data) return { conversationIds: [], isFailed: true };

    const rows = data as { conversation_id: string }[];
    return { conversationIds: [...new Set(rows.map((row) => row.conversation_id))], isFailed: false };
  }

  return {
    state,
    visibleConversations,
    load,
    subscribe,
    unsubscribe,
    setPinned,
    rename,
    hide,
    unhide,
    deleteHidden,
    searchMessages,
  };
}
