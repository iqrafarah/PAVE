import type { AuthErrorLike } from '~/utils/auth/authErrors';
import type { MfaStatus } from '~/utils/auth/mfaRoutes';

const AUTHENTICATOR_ISSUER = 'PAVE';
const MISSING_FACTOR_ERROR: AuthErrorLike = { code: 'mfa_factor_not_found' };

export function useMfa() {
  const supabase = useSupabaseClient();

  async function listTotpFactors() {
    const { data, error } = await supabase.auth.mfa.listFactors();
    if (error) return { data: null, error };

    const totpFactors = data.all.filter((factor) => factor.factor_type === 'totp');
    return { data: totpFactors, error: null };
  }

  async function getVerifiedFactorId() {
    const { data: factors, error } = await listTotpFactors();
    if (error) return { data: null, error };

    const verifiedFactor = factors.find((factor) => factor.status === 'verified');
    return { data: verifiedFactor?.id ?? null, error: null };
  }

  async function getMfaStatus(): Promise<{ data: MfaStatus | null; error: AuthErrorLike | null }> {
    const { data: level, error: levelError } =
      await supabase.auth.mfa.getAuthenticatorAssuranceLevel();
    if (levelError) return { data: null, error: levelError };
    if (level.currentLevel === 'aal2') return { data: 'complete', error: null };

    const { data: factorId, error } = await getVerifiedFactorId();
    if (error) return { data: null, error };
    return { data: factorId ? 'needs-verify' : 'needs-setup', error: null };
  }

  async function removeUnfinishedSetups() {
    const { data: factors, error } = await listTotpFactors();
    if (error) return { error };

    const unverifiedFactors = factors.filter((factor) => factor.status === 'unverified');
    for (const factor of unverifiedFactors) {
      const { error: unenrollError } = await supabase.auth.mfa.unenroll({
        factorId: factor.id,
      });
      if (unenrollError) return { error: unenrollError };
    }
    return { error: null };
  }

  async function startSetup() {
    const { error: cleanupError } = await removeUnfinishedSetups();
    if (cleanupError) return { data: null, error: cleanupError };

    const { data, error } = await supabase.auth.mfa.enroll({
      factorType: 'totp',
      issuer: AUTHENTICATOR_ISSUER,
    });
    if (error) return { data: null, error };

    return {
      data: { factorId: data.id, qrCode: data.totp.qr_code, secret: data.totp.secret },
      error: null,
    };
  }

  async function confirmSetup(factorId: string, code: string) {
    const { error } = await supabase.auth.mfa.challengeAndVerify({ factorId, code });
    return { error };
  }

  async function verifyCode(code: string): Promise<{ error: AuthErrorLike | null }> {
    const { data: factorId, error: factorError } = await getVerifiedFactorId();
    if (factorError) return { error: factorError };
    if (!factorId) return { error: MISSING_FACTOR_ERROR };

    const { error } = await supabase.auth.mfa.challengeAndVerify({ factorId, code });
    return { error };
  }

  return { getMfaStatus, startSetup, confirmSetup, verifyCode };
}
