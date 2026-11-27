import type { H3Event } from 'h3';
import { serverSupabaseClient, serverSupabaseUser } from '#supabase/server';
import type { EmailErrorCode } from '#shared/types/email';
import { MailError, type MailCredentials } from './mailbox';
import { decryptSecret } from './secret';

// Who is asking and their mailbox. Everything goes through the learner's own Supabase session, so the row-level
// security of email_accounts decides; this server only adds the key to read the password.

const STATUS: Record<EmailErrorCode, number> = {
  not_signed_in: 401,
  not_configured: 503,
  not_connected: 404,
  not_icloud: 400,
  wrong_password: 400,
  expired: 401,
  network: 502,
  server: 502,
  too_large: 413,
  invalid: 400,
  not_found: 404,
};

export function emailError(code: EmailErrorCode, detail?: string) {
  return createError({ statusCode: STATUS[code], statusMessage: code, data: { code, detail: detail ?? null } });
}

/** Any error of a route as the code the browser understands. */
export function asEmailError(error: unknown) {
  if (error instanceof MailError) return emailError(error.code, error.detail);
  if ((error as { statusCode?: number })?.statusCode) return error;
  return emailError('server', (error as Error)?.message);
}

export function emailSecret(event: H3Event) {
  const secret = useRuntimeConfig(event).emailSecret as string | undefined;
  if (!secret || secret.length < 32) throw emailError('not_configured');
  return secret;
}

export async function signedIn(event: H3Event) {
  const user = await serverSupabaseUser(event);
  const id = user?.sub as string | undefined;
  if (!id) throw emailError('not_signed_in');
  // eslint-disable-next-line @typescript-eslint/no-explicit-any
  const supabase = await serverSupabaseClient<any>(event);
  return { userId: id, supabase };
}

interface AccountRow {
  address: string;
  login_name: string;
  secret: string;
}

/** The connected account, or null. */
export async function connectedAccount(event: H3Event) {
  const { userId, supabase } = await signedIn(event);
  const { data, error } = await supabase.from('email_accounts').select('address,login_name,secret').eq('user_id', userId).maybeSingle();
  if (error) throw emailError('server', error.message);
  return (data as AccountRow | null) ?? null;
}

/** The credentials to log in with; fails when nothing is connected or the password cannot be read any more. */
export async function credentialsOf(event: H3Event): Promise<MailCredentials> {
  const row = await connectedAccount(event);
  if (!row) throw emailError('not_connected');
  const password = decryptSecret(row.secret, emailSecret(event));
  if (!password) throw emailError('expired');
  return { address: row.address, loginName: row.login_name, password };
}

/** Your name in PAVE, as the sender of your mail ("Ravi <ravi@icloud.com>" lands in spam less than a bare address). */
export async function senderName(event: H3Event) {
  const { userId, supabase } = await signedIn(event);
  const { data } = await supabase.from('profiles').select('*').eq('id', userId).maybeSingle();
  const profile = (data ?? {}) as Record<string, unknown>;
  const name = [profile.full_name, profile.display_name, profile.name, [profile.first_name, profile.last_name].filter(Boolean).join(' ')]
    .find((value) => typeof value === 'string' && value.trim());
  return typeof name === 'string' ? name.trim() : null;
}
