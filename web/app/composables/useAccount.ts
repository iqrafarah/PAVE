interface AccountState {
  fullName: string | null;
  legalName: string | null;
  preferredName: string | null;
  email: string | null;
  avatarUrl: string | null;
  avatarPath: string | null;
  originalAvatarUrl: string | null;
  userId: string | null;
  canEdit: boolean;
  isLoaded: boolean;
  isLoading: boolean;
  isSaving: boolean;
  problem: string | null;
}

const AVATAR_BUCKET = 'pave-avatars';
const AVATAR_URL_SECONDS = 3600;

function accountText(value: unknown): string | null {
  return typeof value === 'string' && value.trim() ? value.trim() : null;
}

export function useAccount() {
  const supabase = useUntypedSupabase();
  const state = useState<AccountState>('pave-account', () => ({
    fullName: null, legalName: null, preferredName: null, email: null,
    avatarUrl: null, avatarPath: null, originalAvatarUrl: null, userId: null,
    canEdit: false, isLoaded: false, isLoading: false, isSaving: false, problem: null,
  }));

  async function loadAvatar() {
    state.value.avatarUrl = state.value.originalAvatarUrl;
    if (!state.value.avatarPath) return;
    const { data, error } = await supabase.storage.from(AVATAR_BUCKET).createSignedUrl(state.value.avatarPath, AVATAR_URL_SECONDS);
    if (error) state.value.problem = PERSONAL_LOAD_FAILED;
    else state.value.avatarUrl = data.signedUrl;
  }

  async function load() {
    if (state.value.isLoaded || state.value.isLoading) return;
    state.value.isLoading = true;
    state.value.problem = null;
    try {
      const { data: { user }, error: authError } = await supabase.auth.getUser();
      if (authError || !user) throw new Error('Account unavailable');
      const { data: profile, error } = await supabase.from('profiles').select('*').eq('id', user.id).maybeSingle();
      if (error) throw error;
      const legalName = accountText(profile?.full_name) ?? accountText(user.user_metadata.full_name) ?? accountText(user.user_metadata.name);
      const preferredName = accountText(profile?.preferred_name);
      Object.assign(state.value, {
        userId: user.id, legalName, preferredName,
        fullName: preferredName ?? legalName?.split(/\s+/)[0] ?? accountText(user.user_metadata.first_name),
        email: accountText(profile?.email) ?? user.email ?? null,
        avatarPath: accountText(profile?.avatar_path),
        originalAvatarUrl: accountText(profile?.avatar_url) ?? accountText(user.user_metadata.avatar_url),
        canEdit: Boolean(profile && 'avatar_path' in profile),
        isLoaded: true,
      });
      await loadAvatar();
    } catch {
      state.value.problem = PERSONAL_LOAD_FAILED;
    } finally {
      state.value.isLoading = false;
    }
  }

  async function updateProfile(fields: { preferred_name?: string | null; avatar_path?: string | null }) {
    if (!state.value.canEdit || !state.value.userId) throw new Error('Settings unavailable');
    const { data, error } = await supabase.from('profiles').update(fields).eq('id', state.value.userId).select('id');
    // A successful response with no rows can mean RLS refused the change.
    if (error || !data?.length) throw error ?? new Error('Profile was not updated');
  }

  async function saveName(value: string) {
    const name = value.trim().replace(/\s+/g, ' ') || null;
    if (name && [...name].length > 60) {
      state.value.problem = 'Gebruik hooguit 60 tekens.';
      return false;
    }
    return save(async () => {
      await updateProfile({ preferred_name: name });
      state.value.preferredName = name;
      state.value.fullName = name ?? state.value.legalName?.split(/\s+/)[0] ?? null;
    });
  }

  async function removeStoredAvatar(path: string) {
    const { error } = await supabase.storage.from(AVATAR_BUCKET).remove([path]);
    if (error) state.value.problem = 'Je foto is aangepast, maar het opruimen van de vorige foto lukte niet.';
  }

  async function setAvatar(photo: File) {
    return save(async () => {
      if (!['image/jpeg', 'image/png'].includes(photo.type) || photo.size > 5 * 1024 * 1024) throw new Error('Invalid photo');
      const extension = photo.type === 'image/png' ? 'png' : 'jpg';
      const path = `${state.value.userId}/${crypto.randomUUID()}.${extension}`;
      const oldPath = state.value.avatarPath;
      const { error } = await supabase.storage.from(AVATAR_BUCKET).upload(path, photo, { contentType: photo.type });
      if (error) throw error;
      try {
        await updateProfile({ avatar_path: path });
      } catch (error) {
        await removeStoredAvatar(path);
        throw error;
      }
      state.value.avatarPath = path;
      await loadAvatar();
      if (oldPath) await removeStoredAvatar(oldPath);
    });
  }

  async function removeAvatar() {
    return save(async () => {
      const path = state.value.avatarPath;
      await updateProfile({ avatar_path: null });
      state.value.avatarPath = null;
      state.value.avatarUrl = state.value.originalAvatarUrl;
      if (path) await removeStoredAvatar(path);
    });
  }

  async function save(action: () => Promise<void>) {
    if (state.value.isSaving) return false;
    state.value.problem = null;
    if (!state.value.canEdit) {
      state.value.problem = PERSONAL_NOT_READY;
      return false;
    }
    state.value.isSaving = true;
    try {
      await action();
      return true;
    } catch {
      state.value.problem = PERSONAL_SAVE_FAILED;
      return false;
    } finally {
      state.value.isSaving = false;
    }
  }

  return { state, load, saveName, setAvatar, removeAvatar };
}
