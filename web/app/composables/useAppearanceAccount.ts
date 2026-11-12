import type { Ref } from 'vue';
import type { Personalisation } from '~/utils/appearance';
import { appearanceToProfile } from '~/utils/appearance';

interface AppearanceAccountState {
  userId: string | null;
  generation: number;
  revision: number;
  savedRevision: number;
  isLoaded: boolean;
  isLoading: boolean;
  isSaving: boolean;
  canSave: boolean;
  supportsCustomColor: boolean;
  problem: string | null;
}

const DEFAULT_SYNC: AppearanceAccountState = {
  userId: null, generation: 0, revision: 0, savedRevision: 0,
  isLoaded: false, isLoading: false, isSaving: false, canSave: false,
  supportsCustomColor: false, problem: null,
};

export function useAppearanceAccount(preferences: Ref<Personalisation>, restore: (profile: Record<string, unknown>) => void) {
  const supabase = useUntypedSupabase();
  const user = useSupabaseUser();
  const sync = useState<AppearanceAccountState>('pave-appearance-account', () => ({ ...DEFAULT_SYNC }));

  function resetAccount() {
    sync.value = { ...DEFAULT_SYNC, generation: sync.value.generation + 1 };
  }

  function isCurrent(userId: string, generation: number) {
    return user.value?.sub === userId && sync.value.generation === generation;
  }

  async function loadAccount() {
    const userId = user.value?.sub;
    if (!userId) { resetAccount(); return; }
    if (sync.value.userId === userId && (sync.value.isLoaded || sync.value.isLoading)) return;
    if (sync.value.userId && sync.value.userId !== userId) resetAccount();
    const generation = ++sync.value.generation;
    Object.assign(sync.value, { userId, isLoading: true, problem: null });
    try {
      // Reading the whole own row also works before the optional appearance columns exist.
      const { data, error } = await supabase.from('profiles').select('*').eq('id', userId).maybeSingle();
      if (!isCurrent(userId, generation)) return;
      if (error) throw error;
      sync.value.canSave = Boolean(data && ['theme_color', 'text_size', 'vault_layout'].every((key) => key in data));
      sync.value.supportsCustomColor = Boolean(data && 'theme_custom_color' in data);
      sync.value.isLoaded = true;
      // A choice made while loading must win over the earlier server response.
      if (sync.value.canSave && sync.value.revision === 0) restore(data!);
    } catch {
      if (isCurrent(userId, generation)) sync.value.problem = PERSONAL_SYNC_LOAD_FAILED;
    } finally {
      if (isCurrent(userId, generation)) sync.value.isLoading = false;
    }
    if (isCurrent(userId, generation) && sync.value.canSave && sync.value.revision > 0) await saveAccount();
  }

  function changed() {
    sync.value.revision += 1;
  }

  async function saveAccount() {
    if (!sync.value.isLoaded) {
      await loadAccount();
      if (!sync.value.isLoaded) return;
    }
    const { userId, generation } = sync.value;
    if (!userId || !sync.value.canSave || sync.value.isSaving || !isCurrent(userId, generation)) return;
    sync.value.isSaving = true;
    sync.value.problem = null;
    try {
      // Serialize writes so a slow earlier colour choice cannot overwrite the latest choice.
      while (sync.value.savedRevision < sync.value.revision && isCurrent(userId, generation)) {
        if (preferences.value.theme === 'custom' && !sync.value.supportsCustomColor) {
          sync.value.problem = PERSONAL_CUSTOM_LOCAL;
          return;
        }
        const revision = sync.value.revision;
        const fields = appearanceToProfile(preferences.value, sync.value.supportsCustomColor);
        const { data, error } = await supabase.from('profiles').update(fields).eq('id', userId).select('id');
        if (!isCurrent(userId, generation)) return;
        if (error || !data?.length) throw error ?? new Error('Profile was not updated');
        sync.value.savedRevision = revision;
      }
    } catch {
      if (isCurrent(userId, generation)) sync.value.problem = PERSONAL_SYNC_FAILED;
    } finally {
      if (isCurrent(userId, generation)) sync.value.isSaving = false;
    }
  }

  return { sync, changed, loadAccount, saveAccount, resetAccount };
}
