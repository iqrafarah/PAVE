import * as OTPAuth from 'npm:otpauth@9';
import { admin, readBody, respond, servePost, sha256Hex } from '../_shared/http.ts';

const MAX_FAILED_ATTEMPTS = 5;
const ATTEMPT_WINDOW_MINUTES = 15;
const RESET_TOKEN_VALID_MINUTES = 10;
const RESET_TOKEN_BYTES = 32;
const TOTP_PERIOD_SECONDS = 30;
const TOTP_DIGITS = 6;
const ALLOWED_CLOCK_DRIFT_STEPS = 1;

const SIX_DIGITS = /^\d{6}$/;
const BASE32_SECRET = /^[A-Z2-7]+=*$/;

function isValidTotpCode(secret: string, code: string) {
  const totp = new OTPAuth.TOTP({
    secret: OTPAuth.Secret.fromBase32(secret),
    algorithm: 'SHA1',
    digits: TOTP_DIGITS,
    period: TOTP_PERIOD_SECONDS,
  });
  return totp.validate({ token: code, window: ALLOWED_CLOCK_DRIFT_STEPS }) !== null;
}

async function isRateLimited(email: string) {
  const { data, error } = await admin.rpc('count_password_reset_failures', {
    p_email: email,
    p_window_minutes: ATTEMPT_WINDOW_MINUTES,
  });
  if (error) throw error;
  return data >= MAX_FAILED_ATTEMPTS;
}

async function findTotpFactor(email: string) {
  const { data, error } = await admin.rpc('get_verified_totp_secret', { p_email: email });
  if (error) throw error;
  const factor: { user_id: string; secret: string } | undefined = data?.[0];
  if (factor && !BASE32_SECRET.test(factor.secret)) {
    throw new Error('TOTP secret is not stored as plain base32; is MFA secret encryption enabled?');
  }
  return factor ?? null;
}

async function createResetToken(userId: string) {
  const randomBytes = crypto.getRandomValues(new Uint8Array(RESET_TOKEN_BYTES));
  const resetToken = Array.from(randomBytes, (byte) => byte.toString(16).padStart(2, '0')).join('');

  const { error } = await admin.rpc('create_password_reset_token', {
    p_user_id: userId,
    p_token_hash: await sha256Hex(resetToken),
    p_valid_minutes: RESET_TOKEN_VALID_MINUTES,
  });
  if (error) throw error;
  return resetToken;
}

servePost(async (request) => {
  const read = await readBody(request);
  const email = read('email').trim().toLowerCase();
  const code = read('code').trim();

  if (!email || !SIX_DIGITS.test(code)) return respond(400, { error: 'invalid_credentials' });
  if (await isRateLimited(email)) return respond(429, { error: 'too_many_attempts' });

  const factor = await findTotpFactor(email);
  if (!factor || !isValidTotpCode(factor.secret, code)) {
    await admin.rpc('record_password_reset_failure', { p_email: email });
    return respond(400, { error: 'invalid_credentials' });
  }

  return respond(200, { resetToken: await createResetToken(factor.user_id) });
});
