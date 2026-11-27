import { asEmailError, emailError, signedIn } from '../../utils/email/account';

// Disconnecting: PAVE forgets the password. The mail stays in the mailbox.
export default defineEventHandler(async (event) => {
  try {
    const { userId, supabase } = await signedIn(event);
    const { error } = await supabase.from('email_accounts').delete().eq('user_id', userId);
    if (error) throw emailError('server', error.message);
    return { ok: true };
  } catch (error) {
    throw asEmailError(error);
  }
});
