import { createCipheriv, createDecipheriv, createHash, randomBytes } from 'node:crypto';

// The app-specific password in email_accounts.secret: AES-256-GCM with a key only this server has (NUXT_EMAIL_SECRET),
// so the database and the browser only ever hold the encrypted text. "v1:<iv>:<tag>:<ciphertext>", base64.

const VERSION = 'v1';

function key(secret: string) {
  return createHash('sha256').update(secret, 'utf8').digest();
}

export function encryptSecret(plain: string, secret: string) {
  const iv = randomBytes(12);
  const cipher = createCipheriv('aes-256-gcm', key(secret), iv);
  const data = Buffer.concat([cipher.update(plain, 'utf8'), cipher.final()]);
  return [VERSION, iv.toString('base64'), cipher.getAuthTag().toString('base64'), data.toString('base64')].join(':');
}

/** Null when it cannot be read: another key, or changed in the database. */
export function decryptSecret(stored: string, secret: string) {
  const [version, iv, tag, data] = stored.split(':');
  if (version !== VERSION || !iv || !tag || !data) return null;
  try {
    const decipher = createDecipheriv('aes-256-gcm', key(secret), Buffer.from(iv, 'base64'));
    decipher.setAuthTag(Buffer.from(tag, 'base64'));
    return Buffer.concat([decipher.update(Buffer.from(data, 'base64')), decipher.final()]).toString('utf8');
  } catch {
    return null;
  }
}
