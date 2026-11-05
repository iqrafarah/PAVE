export type MfaStatus = 'complete' | 'needs-verify' | 'needs-setup';

const AUTHENTICATOR_NAME = 'Authenticator app';

export function useMfa() {
  const supabase = useSupabaseClient();

  async function getVerifiedFactorId() {
    const { data, error } = await supabase.auth.mfa.listFactors();
    if (error) return { data: null, error };
    const factorId = data.totp[0]?.id ?? null;
    return { data: factorId, error: null };
  }

  async function getMfaStatus() {
    const { data: level, error: levelError } =
      await supabase.auth.mfa.getAuthenticatorAssuranceLevel();
    if (levelError) return { data: null, error: levelError };
    if (level.currentLevel === 'aal2') {
      return { data: 'complete' as MfaStatus, error: null };
    }

    const { data: factorId, error } = await getVerifiedFactorId();
    if (error) return { data: null, error };
    const status: MfaStatus = factorId ? 'needs-verify' : 'needs-setup';
    return { data: status, error: null };
  }

  async function removeUnfinishedSetups() {
    const { data, error } = await supabase.auth.mfa.listFactors();
    if (error) return { error };

    const unverifiedFactors = data.all.filter(
      (factor) => factor.factor_type === 'totp' && factor.status === 'unverified',
    );
    for (const factor of unverifiedFactors) {
      const { error: unenrollError } = await supabase.auth.mfa.unenroll({
        factorId: factor.id,
      });
      if (unenrollError) return { error: unenrollError };
    }
    return { error: null };
  }

  async function enrollTotp() {
    const { error: cleanupError } = await removeUnfinishedSetups();
    if (cleanupError) return { data: null, error: cleanupError };

    const { data, error } = await supabase.auth.mfa.enroll({
      factorType: 'totp',
      friendlyName: AUTHENTICATOR_NAME,
    });
    if (error) return { data: null, error };

    return {
      data: { factorId: data.id, qrCode: data.totp.qr_code, secret: data.totp.secret },
      error: null,
    };
  }

  function verifyTotp(factorId: string, code: string) {
    return supabase.auth.mfa.challengeAndVerify({ factorId, code });
  }

  return { getMfaStatus, getVerifiedFactorId, enrollTotp, verifyTotp };
}
