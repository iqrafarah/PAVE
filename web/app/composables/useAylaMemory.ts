import type { MemoryCategory, MemoryNote, MemorySuggestion } from '~/types/ayla';

export type MemoryStatus = 'idle' | 'loading' | 'ready' | 'notSetUp' | 'failed';

interface MemoryState {
  notes: MemoryNote[];
  isEnabled: boolean;
  status: MemoryStatus;
}

interface MemoryRow {
  id: string;
  text: string;
  category?: string | null;
  source: MemoryNote['source'];
  conversation_id: string | null;
  created_at: string;
  updated_at: string;
}

function toNote(row: MemoryRow): MemoryNote {
  return {
    id: row.id,
    text: row.text,
    category: toMemoryCategory(row.category),
    source: row.source,
    conversationId: row.conversation_id,
    createdAt: row.created_at,
    updatedAt: row.updated_at,
  };
}

function hasChangedRows(result: { data: unknown[] | null; error: unknown }) {
  return !result.error && Boolean(result.data?.length);
}

/** What Ayla remembers about the user (docs/ayla.md, section 5). Nothing changes without the user's click. */
export function useAylaMemory() {
  const supabase = useUntypedSupabase();
  const state = useState<MemoryState>('ayla-memory', () => ({
    notes: [],
    isEnabled: true,
    status: 'idle',
  }));

  async function load() {
    if (state.value.status !== 'ready') state.value.status = 'loading';

    const [notesResult, settingsResult] = await Promise.all([
      supabase.from('ayla_memories').select('*').order('created_at', { ascending: false }),
      supabase.from('ayla_settings').select('memory_enabled').maybeSingle(),
    ]);
    if (isMissingTable(notesResult.error) || isMissingTable(settingsResult.error)) {
      state.value.status = 'notSetUp';
      return;
    }
    if (notesResult.error || settingsResult.error) {
      state.value.status = 'failed';
      return;
    }
    const settings = settingsResult.data as { memory_enabled: boolean } | null;
    state.value.notes = (notesResult.data as MemoryRow[]).map(toNote);
    // Without a settings row the memory is on.
    state.value.isEnabled = settings?.memory_enabled ?? true;
    state.value.status = 'ready';
  }

  /** Inserts a note. Before the category column exists Supabase refuses it (PGRST204), so it is sent without. */
  async function insertNote(values: Record<string, unknown>) {
    const result = await supabase.from('ayla_memories').insert(values).select();
    if (!isMissingColumn(result.error)) return result;

    const { category: _category, ...withoutCategory } = values;
    return supabase.from('ayla_memories').insert(withoutCategory).select();
  }

  async function addNote(text: string, category: MemoryCategory) {
    const result = await insertNote({ text: text.trim(), category, source: 'user' });
    if (!hasChangedRows(result)) return { isFailed: true };

    await load();
    return { isFailed: false };
  }

  async function updateNote(id: string, text: string, category: MemoryCategory) {
    const values = { text: text.trim(), category, updated_at: new Date().toISOString() };
    let result = await supabase.from('ayla_memories').update(values).eq('id', id).select('id');
    if (isMissingColumn(result.error)) {
      const { category: _category, ...withoutCategory } = values;
      result = await supabase.from('ayla_memories').update(withoutCategory).eq('id', id).select('id');
    }
    if (!hasChangedRows(result)) return { isFailed: true };

    await load();
    return { isFailed: false };
  }

  async function deleteNote(id: string) {
    const result = await supabase.from('ayla_memories').delete().eq('id', id).select('id');
    if (!hasChangedRows(result)) return { isFailed: true };

    state.value.notes = state.value.notes.filter((note) => note.id !== id);
    return { isFailed: false };
  }

  async function forgetAll() {
    const { error } = await supabase.from('ayla_memories').delete().not('id', 'is', null);
    if (error) return { isFailed: true };

    state.value.notes = [];
    return { isFailed: false };
  }

  async function setEnabled(isEnabled: boolean) {
    const previous = state.value.isEnabled;
    state.value.isEnabled = isEnabled;
    const { error } = await supabase
      .from('ayla_settings')
      .upsert({ memory_enabled: isEnabled, updated_at: new Date().toISOString() }, { onConflict: 'user_id' });
    if (error) state.value.isEnabled = previous;
    return { isFailed: Boolean(error) };
  }

  function findNoteByText(text: string) {
    return state.value.notes.find((note) => note.text === text);
  }

  /** The suggestions still worth asking about: not already known, and old notes that still exist. */
  function getOpenSuggestions(suggestions: MemorySuggestion[]) {
    return suggestions
      .map((suggestion) => {
        const isKnown = state.value.notes.some((note) => noteCovers(note.text, suggestion.text));
        const text = suggestion.text && !isKnown ? suggestion.text : '';
        const replaces = suggestion.replaces && findNoteByText(suggestion.replaces) ? suggestion.replaces : undefined;
        return { text, category: suggestion.category, replaces };
      })
      .filter((suggestion) => suggestion.text || suggestion.replaces);
  }

  /** Saves the ticked new facts and removes the ticked old notes, after "Onthouden" / "Bijwerken" / "Weghalen". */
  async function applySuggestions(
    newFacts: MemorySuggestion[],
    notesToRemove: string[],
    conversationId: string | null,
  ) {
    for (const fact of newFacts) {
      const result = await insertNote({
        text: fact.text,
        category: fact.category,
        source: 'ayla',
        conversation_id: conversationId,
      });
      if (!hasChangedRows(result)) return { isFailed: true };
    }
    for (const noteText of notesToRemove) {
      const note = findNoteByText(noteText);
      if (!note) continue;
      const { isFailed } = await deleteNote(note.id);
      if (isFailed) return { isFailed: true };
    }
    await load();
    return { isFailed: false };
  }

  return {
    state,
    load,
    addNote,
    updateNote,
    deleteNote,
    forgetAll,
    setEnabled,
    getOpenSuggestions,
    applySuggestions,
  };
}
