export type EmailLinkType = 'invite' | 'email' | 'signup';

export function useAuth() {
  const supabase = useSupabaseClient();
  const user = useSupabaseUser();
  const isPasswordReset = useState('is-password-reset', () => false);
  const confirmUrl = `${useRequestURL().origin}/confirm`;

  async function signIn(email: string, password: string) {
    isPasswordReset.value = false;
    const { error } = await supabase.auth.signInWithPassword({
      email,
      password,
    });
    return { error };
  }

  /** Self sign-up. The account only works after the link in the confirmation email (then two-step setup follows). */
  async function signUp(fields: { email: string; password: string; firstName: string; lastName: string }) {
    const firstName = fields.firstName.trim();
    const lastName = fields.lastName.trim();
    const { data, error } = await supabase.auth.signUp({
      email: fields.email,
      password: fields.password,
      options: {
        emailRedirectTo: confirmUrl,
        data: { first_name: firstName, last_name: lastName, full_name: `${firstName} ${lastName}` },
      },
    });
    // With email confirmation switched off Supabase signs the user in at once (a session): no email is sent then.
    // For an address that already has an account Supabase answers as if it worked, but the user has no identities.
    const isExisting = !error && data?.user?.identities?.length === 0;
    return { error, hasSession: Boolean(data?.session), isExisting };
  }

  /** The 6-digit code from the sign-up email. Confirms the address and signs the user in (aal1). */
  async function verifySignUpCode(email: string, code: string) {
    const { error } = await supabase.auth.verifyOtp({ email, token: code, type: 'signup' });
    return { error };
  }

  async function resendVerificationEmail(email: string) {
    const { error } = await supabase.auth.resend({
      type: 'signup',
      email,
      options: { emailRedirectTo: confirmUrl },
    });
    return { error };
  }

  async function signOut() {
    isPasswordReset.value = false;
    const { error } = await supabase.auth.signOut({ scope: 'local' });
    if (!error) await navigateTo('/login');
    return { error };
  }

  async function sendPasswordResetCode(email: string) {
    const { error } = await supabase.auth.resetPasswordForEmail(email);
    return { error };
  }

  async function verifyPasswordResetCode(email: string, code: string) {
    const { error } = await supabase.auth.verifyOtp({
      email,
      token: code,
      type: 'recovery',
    });
    if (!error) isPasswordReset.value = true;
    return { error };
  }

  /**
   * After a new password every session ends, on every device and in every tab ('global'): whoever was signed in
   * with the old password is out and must sign in again. If that fails, at least this browser is signed out.
   */
  async function finishPasswordReset() {
    isPasswordReset.value = false;
    const { error } = await supabase.auth.signOut({ scope: 'global' });
    if (!error) return { error };
    const { error: localError } = await supabase.auth.signOut({ scope: 'local' });
    return { error: localError };
  }

  async function verifyEmailLink(tokenHash: string, type: EmailLinkType) {
    const { error } = await supabase.auth.verifyOtp({ token_hash: tokenHash, type });
    return { error };
  }

  async function updatePassword(password: string) {
    const { error } = await supabase.auth.updateUser({ password });
    return { error };
  }

  return {
    user,
    isPasswordReset,
    signIn,
    signUp,
    verifySignUpCode,
    resendVerificationEmail,
    signOut,
    sendPasswordResetCode,
    verifyPasswordResetCode,
    verifyEmailLink,
    updatePassword,
    finishPasswordReset,
  };
}
