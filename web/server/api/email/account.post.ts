import type { EmailAccount } from '#shared/types/email';
import { asEmailError, emailError, emailSecret, signedIn } from '../../utils/email/account';
import { verifyLogin } from '../../utils/email/mailbox';
import { encryptSecret } from '../../utils/email/secret';

// Connecting iCloud Mail (iOS EmailAccountsScreen): the address and an app-specific password, checked by logging in
// once, and kept (encrypted) only when that works.
const ICLOUD_DOMAINS = ['icloud.com', 'me.com', 'mac.com'];

export default defineEventHandler(async (event): Promise<EmailAccount> => {
  try {
    const secret = emailSecret(event);
    const { userId, supabase } = await signedIn(event);
    const body = await readBody<{ address?: unknown; password?: unknown }>(event);
    const address = typeof body?.address === 'string' ? body.address.trim().toLowerCase() : '';
    // Apple shows the password as "abcd-efgh-ijkl-mnop"; spaces from copying do not belong to it.
    const password = typeof body?.password === 'string' ? body.password.replace(/\s/g, '') : '';
    if (!/^[^@\s]+@[^@\s]+$/.test(address) || !password || password.length > 200) throw emailError('invalid');
    if (!ICLOUD_DOMAINS.includes(address.split('@')[1] ?? '')) throw emailError('not_icloud');

    const loginName = await verifyLogin(address, password);
    const { error } = await supabase.from('email_accounts').upsert({
      user_id: userId,
      provider: 'icloud',
      address,
      login_name: loginName,
      secret: encryptSecret(password, secret),
      updated_at: new Date().toISOString(),
    });
    if (error) throw emailError('server', error.message);
    return { address };
  } catch (error) {
    throw asEmailError(error);
  }
});
