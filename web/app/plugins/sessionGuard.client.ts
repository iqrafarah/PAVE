// Keeps a signed-out user out. When the session has ended somewhere else (a new password, signing out in another
// tab), an open page would otherwise keep half working until its token runs out. This checks the session with the
// server when the page comes back into view and now and then while moving around, and goes to the login screen as
// soon as the session is gone.
const LOGIN_PATH = '/login';
const PUBLIC_PATHS = [LOGIN_PATH, '/forgot-password', '/confirm', '/password-updated', '/set-password'];
const CHECK_EVERY_MS = 30_000;
// The server says the session no longer exists (401/403), as opposed to "no connection".
const SESSION_GONE_STATUSES = [401, 403];

export default defineNuxtPlugin(() => {
  const supabase = useSupabaseClient();
  const router = useRouter();
  let lastCheck = 0;
  let isChecking = false;

  function isPublicPath() {
    return PUBLIC_PATHS.includes(router.currentRoute.value.path);
  }

  async function leave() {
    // Local only: the session is already gone on the server; this clears what the browser still holds.
    await supabase.auth.signOut({ scope: 'local' }).catch(() => {});
    if (!isPublicPath()) await navigateTo(LOGIN_PATH);
  }

  async function check() {
    if (isChecking || isPublicPath() || Date.now() - lastCheck < CHECK_EVERY_MS) return;
    const { data } = await supabase.auth.getSession();
    if (!data.session) return;
    isChecking = true;
    lastCheck = Date.now();
    const { error } = await supabase.auth.getUser();
    isChecking = false;
    if (error && SESSION_GONE_STATUSES.includes(error.status ?? 0)) await leave();
  }

  // Signing out in another tab of this browser arrives here at once.
  supabase.auth.onAuthStateChange((event) => {
    if (event === 'SIGNED_OUT' && !isPublicPath()) navigateTo(LOGIN_PATH);
  });
  document.addEventListener('visibilitychange', () => {
    if (document.visibilityState === 'visible') check();
  });
  window.addEventListener('focus', check);
  router.afterEach(() => {
    check();
  });
  setInterval(check, CHECK_EVERY_MS);
});
