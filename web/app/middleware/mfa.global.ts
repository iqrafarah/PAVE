const PUBLIC_PATHS = ['/login', '/confirm'];
const SETUP_PATH = '/mfa-setup';
const VERIFY_PATH = '/mfa-verify';

export default defineNuxtRouteMiddleware(async (to) => {
  if (PUBLIC_PATHS.includes(to.path)) return;

  const session = useSupabaseSession();
  if (!session.value) return;

  const { data: status } = await useMfa().getMfaStatus();

  if (status === 'complete') {
    const isOnMfaStep = to.path === SETUP_PATH || to.path === VERIFY_PATH;
    if (isOnMfaStep) return navigateTo('/');
    return;
  }

  // Fail closed: if the status cannot be loaded, the user still has to verify.
  const requiredPath = status === 'needs-setup' ? SETUP_PATH : VERIFY_PATH;
  if (to.path !== requiredPath) return navigateTo(requiredPath);
});
