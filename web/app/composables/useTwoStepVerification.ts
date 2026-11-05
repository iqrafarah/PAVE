const AUTHENTICATOR_NAME = 'Authenticator app';

export function useTwoStepVerification() {
  const supabase = useSupabaseClient();

  async function isTwoStepComplete() {
    const { data, error } = await supabase.auth.mfa.getAuthenticatorAssuranceLevel();
    if (error) return false;
    return data.currentLevel === 'aal2';
  }

  async function getVerifiedFactorId() {
    const { data, error } = await supabase.auth.mfa.listFactors();
    if (error) return { factorId: null, error };
    const factorId = data.totp[0]?.id ?? null;
    return { factorId, error: null };
  }

  async function removeUnfinishedEnrollments() {
    const { data, error } = await supabase.auth.mfa.listFactors();
    if (error) return { error };

    const unverifiedFactors = data.all.filter(
      (factor) => factor.factor_type === 'totp' && factor.status === 'unverified',
    );
    for (const factor of unverifiedFactors) {
      const { error: unenrollError } = await supabase.auth.mfa.unenroll({ factorId: factor.id });
      if (unenrollError) return { error: unenrollError };
    }
    return { error: null };
  }

  async function enrollAuthenticator() {
    const { error: cleanupError } = await removeUnfinishedEnrollments();
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

  async function verifyCode(factorId: string, code: string) {
    const { error } = await supabase.auth.mfa.challengeAndVerify({ factorId, code });
    return { error };
  }

  return { isTwoStepComplete, getVerifiedFactorId, enrollAuthenticator, verifyCode };
}
