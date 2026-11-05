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

  return { user, signIn, resendVerificationEmail, signOut };
}
