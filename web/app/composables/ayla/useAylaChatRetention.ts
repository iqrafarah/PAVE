export type ChatRetentionStatus = 'idle' | 'loading' | 'ready' | 'unavailable';

interface RetentionState {
  /** How many days a chat is kept; null is for ever. */
  days: number | null;
  status: ChatRetentionStatus;
}

/**
 * "Chats automatisch verwijderen": the account's choice in profiles.chat_expiry_days, the same one the iPhone shows
 * (migrations 20261120120000 and 20261120150000). The database does the deleting, once an hour, so it works with the
 * app closed. Before the migration ran the choice is hidden ('unavailable').
 */
export function useAylaChatRetention() {
  const supabase = useUntypedSupabase();
  const user = useSupabaseUser();
  const state = useState<RetentionState>('ayla-chat-retention', () => ({ days: null, status: 'idle' }));

  async function load() {
    const userId = user.value?.sub;
    if (!userId) {
      state.value.status = 'unavailable';
      return;
    }
    state.value.status = 'loading';
    const { data, error } = await supabase.from('profiles').select('chat_expiry_days').eq('id', userId).maybeSingle();
    // Missing column: the migration has not run yet. Any other error hides the choice too.
    if (error) {
      state.value.status = 'unavailable';
      return;
    }
    state.value.days = (data as { chat_expiry_days: number | null } | null)?.chat_expiry_days ?? null;
    state.value.status = 'ready';
  }

  async function setDays(days: number | null) {
    const userId = user.value?.sub;
    if (!userId) return { isFailed: true };
    const previous = state.value.days;
    state.value.days = days;
    const { data, error } = await supabase.from('profiles').update({ chat_expiry_days: days }).eq('id', userId).select('id');
    // Row-level security turns a refused change into "nothing changed": that is not a success.
    const isFailed = Boolean(error) || !data?.length;
    if (isFailed) state.value.days = previous;
    return { isFailed };
  }

  return { state, load, setDays };
}
