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
// The link to your own photo works for a day and is kept with the rest of the account, so the browser can show the
// photo it already has instead of fetching it again on every page.
const AVATAR_URL_SECONDS = 86_400;
// Asked for a new link once the kept one has less than this left.
const AVATAR_URL_MARGIN_MS = 10 * 60 * 1000;
const CACHE_KEY = 'pave-account';
const CACHE_DAYS = 30;
// A cookie holds about 4000 characters; above this the link to the photo is left out and fetched again instead.
const CACHE_MAX_LENGTH = 3200;

// What is kept in this browser between visits: enough to show your name and photo at once. It is a cookie and not
// browser storage, so the server already knows it when it builds the page: your name and photo are in the page as it
// arrives, instead of "Je account" until the scripts have started. It is checked against the database right after, and
// thrown away when you sign out or another account signs in.
type CachedAccount = Pick<
  AccountState,
  'userId' | 'fullName' | 'legalName' | 'preferredName' | 'email' | 'avatarUrl' | 'avatarPath' | 'originalAvatarUrl' | 'canEdit'
> & { avatarUrlExpiresAt: number | null };

const EMPTY_ACCOUNT: AccountState = {
  fullName: null, legalName: null, preferredName: null, email: null,
  avatarUrl: null, avatarPath: null, originalAvatarUrl: null, userId: null,
  canEdit: false, isLoaded: false, isLoading: false, isSaving: false, problem: null,
};

/** Whether the kept link to the own photo still works. A link that ran out would show a broken photo. */
function isLinkAlive(cached: CachedAccount) {
  return Boolean(cached.avatarPath && cached.avatarUrlExpiresAt && cached.avatarUrlExpiresAt > Date.now());
}

/** The account as it shows from the kept copy; the letter of your name stands in for a photo whose link ran out. */
function accountFromCache(cached: CachedAccount): AccountState {
  const { avatarUrlExpiresAt: _, ...account } = cached;
  return { ...EMPTY_ACCOUNT, ...account, avatarUrl: account.avatarPath && !isLinkAlive(cached) ? null : account.avatarUrl, isLoaded: true };
}

function accountText(value: unknown): string | null {
  return typeof value === 'string' && value.trim() ? value.trim() : null;
}

export function useAccount() {
  const supabase = useUntypedSupabase();
  // Who is signed in according to the session the page came with: known at once, without asking the server.
  const signedIn = useSupabaseUser();
  const kept = useCookie<CachedAccount | null>(CACHE_KEY, {
    default: () => null,
    maxAge: CACHE_DAYS * 86_400,
    sameSite: 'lax',
    secure: !import.meta.dev,
  });

  /** The kept copy, but only when it belongs to the account that is signed in. */
  function readCache(userId: string | undefined): CachedAccount | null {
    const cached = kept.value;
    return cached && typeof cached === 'object' && userId && cached.userId === userId ? cached : null;
  }

  // Filled from the kept copy the moment the page is built (on the server too), so the first thing you see is right.
  const state = useState<AccountState>('pave-account', () => {
    const cached = readCache(signedIn.value?.sub);
    return cached ? accountFromCache(cached) : { ...EMPTY_ACCOUNT };
  });

  // The photo the link in `avatarUrl` belongs to, and until when that link works.
  const avatarLink = useState<{ path: string; expiresAt: number } | null>('pave-account-avatar-link', () => {
    const cached = readCache(signedIn.value?.sub);
    return cached && isLinkAlive(cached) ? { path: cached.avatarPath!, expiresAt: cached.avatarUrlExpiresAt! } : null;
  });
  // The account the database was asked about in this visit; the kept copy is shown before that.
  const checkedUserId = useState<string | null>('pave-account-checked', () => null);

  function writeCache() {
    if (!state.value.userId) return;
    const { userId, fullName, legalName, preferredName, email, avatarUrl, avatarPath, originalAvatarUrl, canEdit } = state.value;
    const cached: CachedAccount = {
      userId, fullName, legalName, preferredName, email, avatarUrl, avatarPath, originalAvatarUrl, canEdit,
      avatarUrlExpiresAt: avatarLink.value?.expiresAt ?? null,
    };
    if (encodeURIComponent(JSON.stringify(cached)).length > CACHE_MAX_LENGTH) {
      cached.avatarUrl = cached.originalAvatarUrl && cached.originalAvatarUrl.length < 300 && !cached.avatarPath ? cached.originalAvatarUrl : null;
      cached.avatarUrlExpiresAt = null;
    }
    kept.value = cached;
  }

  /** Throws the kept copy away: it belongs to the account that just signed out. */
  function forget() {
    kept.value = null;
    avatarLink.value = null;
    checkedUserId.value = null;
    state.value = { ...EMPTY_ACCOUNT };
  }

  async function loadAvatar() {
    const path = state.value.avatarPath;
    if (!path) {
      avatarLink.value = null;
      state.value.avatarUrl = state.value.originalAvatarUrl;
      return;
    }
    // The link in use is for this photo and still works for a while: keep it, so the photo does not load again.
    if (avatarLink.value?.path === path && state.value.avatarUrl && avatarLink.value.expiresAt - Date.now() > AVATAR_URL_MARGIN_MS) return;
    const { data, error } = await supabase.storage.from(AVATAR_BUCKET).createSignedUrl(path, AVATAR_URL_SECONDS);
    if (error) {
      state.value.problem = PERSONAL_LOAD_FAILED;
      state.value.avatarUrl = state.value.originalAvatarUrl;
      avatarLink.value = null;
    } else {
      state.value.avatarUrl = data.signedUrl;
      avatarLink.value = { path, expiresAt: Date.now() + AVATAR_URL_SECONDS * 1000 };
    }
  }

  /**
   * Shows the account at once from what this browser kept, then checks it against the database in the background
   * (once per visit). The session is read from the browser itself, which saves a round trip to the server; the
   * database still only gives the row of the signed-in account.
   */
  /** Puts what this browser kept for this account on the screen. Nothing is asked from the server for it. */
  function showKept(userId: string) {
    if (state.value.isLoaded) return false;
    const cached = readCache(userId);
    if (!cached) return false;
    avatarLink.value = isLinkAlive(cached) ? { path: cached.avatarPath!, expiresAt: cached.avatarUrlExpiresAt! } : null;
    Object.assign(state.value, accountFromCache(cached));
    return true;
  }

  async function load() {
    if (state.value.isLoading) return;
    state.value.problem = null;
    // First of all, before anything is asked: your name and photo as this browser knows them. Reading the session can
    // take a few seconds after a refresh (it may be renewed first), and the screen must not show "Je account" meanwhile.
    const knownId = signedIn.value?.sub;
    if (knownId && (!state.value.userId || state.value.userId === knownId)) showKept(knownId);
    try {
      const { data: { session } } = await supabase.auth.getSession();
      const user = session?.user;
      if (!user) throw new Error('Account unavailable');
      if (checkedUserId.value === user.id) return;
      // Another account signed in without the page being loaded again: nothing of the previous one may stay.
      if (state.value.userId && state.value.userId !== user.id) {
        avatarLink.value = null;
        Object.assign(state.value, {
          fullName: null, legalName: null, preferredName: null, email: null, avatarUrl: null, avatarPath: null,
          originalAvatarUrl: null, userId: null, canEdit: false, isLoaded: false,
        });
      }

      showKept(user.id);
      // Only without a kept copy is there something to wait for.
      state.value.isLoading = !state.value.isLoaded;

      const { data: profile, error } = await supabase.from('profiles').select('*').eq('id', user.id).maybeSingle();
      if (error) throw error;
      // A change is being saved while the answer was on its way: what is on screen is newer.
      if (state.value.isSaving) return;
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
      checkedUserId.value = user.id;
      writeCache();
    } catch {
      // With a kept copy on screen there is nothing to report: it is checked again on the next page.
      if (!state.value.isLoaded) state.value.problem = PERSONAL_LOAD_FAILED;
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
      avatarLink.value = null;
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
      writeCache();
      return true;
    } catch {
      state.value.problem = PERSONAL_SAVE_FAILED;
      return false;
    } finally {
      state.value.isSaving = false;
    }
  }

  return { state, load, saveName, setAvatar, removeAvatar, forget };
}
