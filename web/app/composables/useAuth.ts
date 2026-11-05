export type EmailLinkType = 'invite' | 'email';

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

  async function finishPasswordReset() {
    isPasswordReset.value = false;
    const { error } = await supabase.auth.signOut({ scope: 'local' });
    return { error };
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
    resendVerificationEmail,
    signOut,
    sendPasswordResetCode,
    verifyPasswordResetCode,
    verifyEmailLink,
    updatePassword,
    finishPasswordReset,
  };
}
