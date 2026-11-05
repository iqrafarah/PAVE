export type EmailLinkType = 'invite' | 'email';

export function useAuth() {
  const supabase = useSupabaseClient();
  const user = useSupabaseUser();
  const confirmUrl = `${useRequestURL().origin}/confirm`;

  async function signIn(email: string, password: string) {
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
    const { error } = await supabase.auth.signOut();
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
    signIn,
    resendVerificationEmail,
    signOut,
    sendPasswordResetCode,
    verifyPasswordResetCode,
    verifyEmailLink,
    updatePassword,
  };
}
