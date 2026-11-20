export type ChatRetentionStatus = 'idle' | 'loading' | 'ready' | 'unavailable' | 'failed';

interface RetentionState {
  retention: PaveRetention;
  status: ChatRetentionStatus;
}

interface RetentionRow {
  chat_expiry_days: number | null;
  chat_expiry_from: string | null;
  chat_expiry_keeps_pinned: boolean | null;
  chat_expiry_keeps_locked: boolean | null;
  ayla_uses_archive: boolean | null;
}

const COLUMNS = 'chat_expiry_days,chat_expiry_from,chat_expiry_keeps_pinned,chat_expiry_keeps_locked,ayla_uses_archive';

function toRetention(row: RetentionRow | null): PaveRetention {
  if (!row) return structuredClone(DEFAULT_RETENTION);
  return {
    chatExpiry: {
      days: row.chat_expiry_days ?? null,
      start: row.chat_expiry_from === 'created' ? 'created' : 'last_message',
      keepsPinned: row.chat_expiry_keeps_pinned ?? true,
      keepsLocked: row.chat_expiry_keeps_locked ?? true,
    },
    aylaUsesArchive: row.ayla_uses_archive ?? false,
  };
}

/**
 * Instellingen › Gegevens bewaren (iOS SettingsRetentionScreen, ProfileService.retention): after how long chats
 * disappear, from when the time runs, whether pinned and locked chats stay, and whether Ayla may use the archive. It is
 * kept in profiles (migrations 20261120120000 and 20261120150000), the same row the iPhone reads. The database does the
 * deleting. Before the migration ran there is nothing to choose ('unavailable').
 */
export function useAylaChatRetention() {
  const supabase = useUntypedSupabase();
  const user = useSupabaseUser();
  const state = useState<RetentionState>('ayla-chat-retention', () => ({
    retention: structuredClone(DEFAULT_RETENTION),
    status: 'idle',
  }));

  async function load() {
    const userId = user.value?.sub;
    if (!userId) {
      state.value.status = 'unavailable';
      return;
    }
    if (state.value.status !== 'ready') state.value.status = 'loading';
    const { data, error } = await supabase.from('profiles').select(COLUMNS).eq('id', userId).maybeSingle();
    if (error) {
      state.value.status = isMissingColumn(error) ? 'unavailable' : 'failed';
      return;
    }
    state.value.retention = toRetention(data as RetentionRow | null);
    state.value.status = 'ready';
  }

  /** Saves the whole choice; the screen changes at once and goes back when Supabase refuses. */
  async function save(next: PaveRetention) {
    const userId = user.value?.sub;
    if (!userId) return { isFailed: true };
    const previous = state.value.retention;
    state.value.retention = next;
    const { data, error } = await supabase
      .from('profiles')
      .update({
        chat_expiry_days: next.chatExpiry.days,
        chat_expiry_from: next.chatExpiry.start,
        chat_expiry_keeps_pinned: next.chatExpiry.keepsPinned,
        chat_expiry_keeps_locked: next.chatExpiry.keepsLocked,
        ayla_uses_archive: next.aylaUsesArchive,
      })
      .eq('id', userId)
      .select('id');
    // Row-level security turns a refused change into "nothing changed": that is not a success.
    const isFailed = Boolean(error) || !data?.length;
    if (isFailed) state.value.retention = previous;
    return { isFailed };
  }

  return { state, load, save };
}
