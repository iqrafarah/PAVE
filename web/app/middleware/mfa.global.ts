import type { MfaStatus } from '~/utils/auth/mfaRoutes';

const LOGIN_PATH = '/login';
const PATHS_WITHOUT_MFA = ['/forgot-password', '/confirm', PASSWORD_UPDATED_PATH];
const MFA_STEP_PATHS = [MFA_SETUP_PATH, MFA_VERIFY_PATH];

function isAllowedBeforeMfa(path: string, status: MfaStatus | null) {
  if (path === getMfaPath(status)) return true;
  // Without a verified authenticator aal2 is impossible, so a password can still be set (invite, reset).
  return path === SET_PASSWORD_PATH && status === 'needs-setup';
}

export default defineNuxtRouteMiddleware(async (to) => {
  if (PATHS_WITHOUT_MFA.includes(to.path)) return;

  const session = useSupabaseSession();
  if (!session.value) return;

  const { data: status } = await useMfa().getMfaStatus();
  if (to.path === LOGIN_PATH) return navigateTo(getMfaPath(status));

  if (status === 'complete') {
    if (MFA_STEP_PATHS.includes(to.path)) return navigateTo(HOME_PATH);
    return;
  }

  if (isAllowedBeforeMfa(to.path, status)) return;
  return navigateTo(getMfaPath(status));
});
