export type MfaStatus = 'complete' | 'needs-verify' | 'needs-setup';

export const MFA_SETUP_PATH = '/mfa-setup';
export const MFA_VERIFY_PATH = '/mfa-verify';
export const MFA_COMPLETE_PATH = '/mfa-complete';
export const SET_PASSWORD_PATH = '/set-password';
export const PASSWORD_UPDATED_PATH = '/password-updated';
export const HOME_PATH = '/';

export function getMfaPath(status: MfaStatus | null) {
  if (status === 'complete') return HOME_PATH;
  if (status === 'needs-setup') return MFA_SETUP_PATH;
  return MFA_VERIFY_PATH;
}
