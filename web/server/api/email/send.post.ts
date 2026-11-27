import type { EmailAddress } from '#shared/types/email';
import { asEmailError, credentialsOf, emailError, senderName } from '../../utils/email/account';
import { MAX_ATTACHMENTS_SIZE, send } from '../../utils/email/mailbox';

// A new message or a reply (iOS EmailComposeSheet and EmailThreadScreen), as multipart form data: "mail" holds the
// JSON below, every "file" is an attachment.
interface MailForm {
  to?: unknown;
  cc?: unknown;
  subject?: unknown;
  text?: unknown;
  inReplyTo?: unknown;
  references?: unknown;
}

function people(value: unknown): EmailAddress[] | null {
  if (!Array.isArray(value)) return [];
  const list = value.map((entry) => {
    const person = entry as EmailAddress;
    const address = typeof person?.address === 'string' ? person.address.trim().toLowerCase() : '';
    if (!/^[^@\s<>]+@[^@\s<>]+\.[^@\s<>]+$/.test(address)) return null;
    return { name: typeof person.name === 'string' && person.name.trim() ? person.name.trim().slice(0, 200) : null, address };
  });
  return list.every((person) => person !== null) ? (list as EmailAddress[]) : null;
}

export default defineEventHandler(async (event) => {
  try {
    const parts = (await readMultipartFormData(event)) ?? [];
    const json = parts.find((part) => part.name === 'mail' && !part.filename);
    const form = json ? (JSON.parse(json.data.toString('utf8')) as MailForm) : null;
    const to = people(form?.to);
    const cc = people(form?.cc);
    if (!form || !to || !cc || !to.length || to.length + cc.length > 50) throw emailError('invalid');
    const text = typeof form.text === 'string' ? form.text.slice(0, 100_000) : '';
    const subject = typeof form.subject === 'string' ? form.subject.replace(/[\r\n]+/g, ' ').trim().slice(0, 300) : '';
    const files = parts
      .filter((part) => part.name === 'file' && part.filename)
      .map((part) => ({ name: part.filename!, mimeType: part.type || 'application/octet-stream', content: part.data }));
    if (!text.trim() && !files.length) throw emailError('invalid');
    if (files.reduce((sum, file) => sum + file.content.length, 0) > MAX_ATTACHMENTS_SIZE) throw emailError('too_large');
    const inReplyTo = typeof form.inReplyTo === 'string' ? form.inReplyTo : null;
    const references = Array.isArray(form.references) ? form.references.filter((id): id is string => typeof id === 'string').slice(-50) : [];

    const credentials = await credentialsOf(event);
    return await send(credentials, { senderName: await senderName(event), to, cc, subject, text, inReplyTo, references, attachments: files });
  } catch (error) {
    throw asEmailError(error);
  }
});
