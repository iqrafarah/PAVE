import { admin, readBody, respond, servePost, sha256Hex } from '../_shared/http.ts';

const MIN_PASSWORD_LENGTH = 12;

const UPPERCASE_LETTER = /[A-Z]/;
const LOWERCASE_LETTER = /[a-z]/;
const DIGIT = /\d/;
const SYMBOL = /[^A-Za-z0-9]/;

function isStrongPassword(password: string) {
  return (
    password.length >= MIN_PASSWORD_LENGTH &&
    UPPERCASE_LETTER.test(password) &&
    LOWERCASE_LETTER.test(password) &&
    DIGIT.test(password) &&
    SYMBOL.test(password)
  );
}

async function consumeResetToken(resetToken: string) {
  const { data, error } = await admin.rpc('consume_password_reset_token', {
    p_token_hash: await sha256Hex(resetToken),
  });
  if (error) throw error;
  const userId: string | null = data;
  return userId;
}

servePost(async (request) => {
  const read = await readBody(request);
  const resetToken = read('resetToken');
  const password = read('password');

  if (!isStrongPassword(password)) return respond(400, { error: 'weak_password' });

  const userId = resetToken ? await consumeResetToken(resetToken) : null;
  if (!userId) return respond(400, { error: 'invalid_token' });

  const { error } = await admin.auth.admin.updateUserById(userId, { password });
  if (error?.code === 'weak_password') return respond(400, { error: 'weak_password' });
  if (error) throw error;

  const { error: revokeError } = await admin.rpc('revoke_user_sessions', { p_user_id: userId });
  if (revokeError) console.error('Password changed, but sessions were not revoked', revokeError);

  return respond(200, { ok: true });
});
