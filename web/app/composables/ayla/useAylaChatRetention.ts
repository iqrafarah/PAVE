export type ChatRetentionStatus = 'idle' | 'loading' | 'ready' | 'unavailable';

interface RetentionState {
  /** How many days a chat is kept; null is for ever. */
  days: number | null;
  status: ChatRetentionStatus;
}

/**
 * "Chats automatisch verwijderen" (ayla_settings.chat_auto_delete_days). The database does the deleting, once an hour,
 * so it works with the app closed. Before the migration ran the choice is hidden ('unavailable').
 */
export function useAylaChatRetention() {
  const supabase = useUntypedSupabase();
  const state = useState<RetentionState>('ayla-chat-retention', () => ({ days: null, status: 'idle' }));

  async function load() {
    state.value.status = 'loading';
    const { data, error } = await supabase.from('ayla_settings').select('chat_auto_delete_days').maybeSingle();
    // Missing column or table: the migration has not run yet. Any other error hides the choice too.
    if (error) {
      state.value.status = 'unavailable';
      return;
    }
    state.value.days = (data as { chat_auto_delete_days: number | null } | null)?.chat_auto_delete_days ?? null;
    state.value.status = 'ready';
  }

  async function setDays(days: number | null) {
    const previous = state.value.days;
    state.value.days = days;
    const { error } = await supabase
      .from('ayla_settings')
      .upsert({ chat_auto_delete_days: days, updated_at: new Date().toISOString() }, { onConflict: 'user_id' });
    if (error) state.value.days = previous;
    return { isFailed: Boolean(error) };
  }

  return { state, load, setDays };
}
