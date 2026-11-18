export type PinCheck = 'right' | 'wrong' | 'blocked' | 'failed';

interface ChatLockState {
  status: 'idle' | 'ready' | 'unavailable';
  hasPin: boolean;
  lockedIds: string[];
  // True after the PIN was entered in this tab. Closing the tab, or "Vergrendel opnieuw", locks everything again.
  isUnlocked: boolean;
  // "Nieuwe vergrendelde chat": the next chat started on the home screen is locked as soon as it exists.
  isNewChatLocked: boolean;
}

/**
 * Locked chats (migration 20261118130000): one PIN per account for all of them. A locked chat leaves the recent list
 * and the search, and opens only after the PIN, which the database checks. Without the migration the status is
 * 'unavailable' and nothing is hidden or offered.
 */
export function useAylaChatLock() {
  const supabase = useUntypedSupabase();
  const state = useState<ChatLockState>('ayla-chat-lock', () => ({
    status: 'idle',
    hasPin: false,
    lockedIds: [],
    isUnlocked: false,
    isNewChatLocked: false,
  }));

  const isAvailable = computed(() => state.value.status === 'ready');

  function isLocked(conversationId: string | null) {
    return Boolean(conversationId) && state.value.lockedIds.includes(conversationId as string);
  }

  async function load() {
    const [pin, locked] = await Promise.all([
      supabase.rpc('ayla_chat_pin_exists'),
      supabase.from('ayla_locked_chats').select('conversation_id'),
    ]);
    if (pin.error || locked.error) {
      state.value.status = 'unavailable';
      return;
    }
    state.value.hasPin = Boolean(pin.data);
    state.value.lockedIds = ((locked.data ?? []) as { conversation_id: string }[]).map((row) => row.conversation_id);
    state.value.status = 'ready';
  }

  /** Makes the PIN, the first time a chat is locked. */
  async function createPin(pin: string) {
    const { error } = await supabase.rpc('ayla_set_chat_pin', { pin });
    if (error) return { isFailed: true };
    state.value.hasPin = true;
    state.value.isUnlocked = true;
    return { isFailed: false };
  }

  async function checkPin(pin: string): Promise<PinCheck> {
    const { data, error } = await supabase.rpc('ayla_check_chat_pin', { pin });
    if (error) return error.message.includes('too_many_attempts') ? 'blocked' : 'failed';
    if (!data) return 'wrong';
    state.value.isUnlocked = true;
    return 'right';
  }

  /** "Nu vergrendelen": locks everything again and leaves for the start screen, like closing the tab. */
  async function relock() {
    state.value.isUnlocked = false;
    state.value.isNewChatLocked = false;
    await navigateTo('/');
  }

  /** "Nieuwe vergrendelde chat": only while unlocked, so it never opens the locked chats without the PIN. */
  async function startLockedChat() {
    if (!state.value.isUnlocked) return;
    state.value.isNewChatLocked = true;
    await navigateTo('/');
  }

  async function lockChat(conversationId: string) {
    const { error } = await supabase.from('ayla_locked_chats').insert({ conversation_id: conversationId });
    if (error) return { isFailed: true };
    state.value.lockedIds = [...state.value.lockedIds, conversationId];
    return { isFailed: false };
  }

  async function unlockChat(conversationId: string) {
    const { data, error } = await supabase
      .from('ayla_locked_chats')
      .delete()
      .eq('conversation_id', conversationId)
      .select('conversation_id');
    if (error || !data?.length) return { isFailed: true };
    state.value.lockedIds = state.value.lockedIds.filter((id) => id !== conversationId);
    return { isFailed: false };
  }

  /** "Pincode vergeten": the database deletes the locked chats and the PIN. */
  async function resetPin() {
    const { error } = await supabase.rpc('ayla_reset_chat_pin');
    if (error) return { isFailed: true };
    state.value.hasPin = false;
    state.value.lockedIds = [];
    state.value.isUnlocked = false;
    return { isFailed: false };
  }

  return { state, isAvailable, isLocked, load, createPin, checkPin, relock, startLockedChat, lockChat, unlockChat, resetPin };
}
