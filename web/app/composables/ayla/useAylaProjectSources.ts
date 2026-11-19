import type { VaultItem } from '~/types/vault';

export type SourcesStatus = 'idle' | 'loading' | 'ready' | 'unavailable';

interface SourcesState {
  // Project id → ids of the vault items that are its sources.
  byProject: Record<string, string[]>;
  status: SourcesStatus;
}

/**
 * The sources of a project: vault items added to it (migration 20261119160000). Ayla uses them in every chat of the
 * project. Until the migration runs the table is missing: the status is then 'unavailable' and the page hides "Bronnen".
 */
export function useAylaProjectSources() {
  const supabase = useUntypedSupabase();
  const vault = useVault();
  const state = useState<SourcesState>('ayla-project-sources', () => ({ byProject: {}, status: 'idle' }));

  async function load(projectId: string) {
    if (state.value.status !== 'ready') state.value.status = 'loading';
    const { data, error } = await supabase
      .from('ayla_project_sources')
      .select('item_id')
      .eq('project_id', projectId)
      .order('created_at', { ascending: false });
    if (error || !data) {
      state.value.status = 'unavailable';
      return;
    }
    state.value.byProject = { ...state.value.byProject, [projectId]: (data as { item_id: string }[]).map((row) => row.item_id) };
    state.value.status = 'ready';
    if (vault.state.value.status !== 'ready') await vault.load();
  }

  /** The items of the project, newest first; an item that is not in the vault any more is skipped. */
  function itemsOf(projectId: string): VaultItem[] {
    const ids = state.value.byProject[projectId] ?? [];
    return ids.map((id) => vault.state.value.items.find((item) => item.id === id)).filter((item): item is VaultItem => Boolean(item));
  }

  async function add(projectId: string, itemIds: string[]) {
    const known = state.value.byProject[projectId] ?? [];
    const fresh = itemIds.filter((id) => !known.includes(id));
    if (!fresh.length) return { isFailed: false };
    const { error } = await supabase
      .from('ayla_project_sources')
      .upsert(fresh.map((itemId) => ({ project_id: projectId, item_id: itemId })), { ignoreDuplicates: true });
    if (error) return { isFailed: true };
    state.value.byProject = { ...state.value.byProject, [projectId]: [...fresh, ...known] };
    return { isFailed: false };
  }

  /** Only the link goes: the item stays in the vault. */
  async function remove(projectId: string, itemId: string) {
    const { data, error } = await supabase
      .from('ayla_project_sources')
      .delete()
      .eq('project_id', projectId)
      .eq('item_id', itemId)
      .select('item_id');
    const isFailed = Boolean(error) || !data?.length;
    if (!isFailed) state.value.byProject = { ...state.value.byProject, [projectId]: (state.value.byProject[projectId] ?? []).filter((id) => id !== itemId) };
    return { isFailed };
  }

  return { state, load, itemsOf, add, remove };
}
