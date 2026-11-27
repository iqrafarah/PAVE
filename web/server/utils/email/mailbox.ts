import { ImapFlow, type ListResponse } from 'imapflow';
import { simpleParser, type AddressObject, type ParsedMail } from 'mailparser';
import nodemailer from 'nodemailer';
import MailComposer from 'nodemailer/lib/mail-composer';
import type { EmailAddress, EmailAttachment, EmailErrorCode, EmailMessage, EmailMessageBody, EmailRef } from '#shared/types/email';
import { isAutomatedMail, stripQuotedText } from './threading';

// iCloud Mail, the mail Mail on the Mac reads too (iOS ICloudMailbox; keep the two the same). Apple offers no sign-in
// for other apps, so it works like any mail program: IMAP to read, SMTP to send, with an app-specific password. Each
// call opens its own connection and closes it again; nothing of the mail is kept on the server.

const IMAP_HOST = 'imap.mail.me.com';
const SMTP_HOST = 'smtp.mail.me.com';
const INBOX = 'INBOX';
/** The newest messages read for the list: the inbox, and more of Verzonden, because that is how PAVE learns who you write with. */
const RECENT_INBOX = 100;
const RECENT_SENT = 200;
const SENT_NAMES = ['Sent Messages', 'Sent', 'Verzonden', 'Sent Items'];
const TRASH_NAMES = ['Deleted Messages', 'Trash', 'Prullenmand', 'Verwijderde berichten', 'Deleted Items'];
const HEADER_FIELDS = [
  'from', 'to', 'cc', 'subject', 'date', 'message-id', 'in-reply-to', 'references',
  'list-unsubscribe', 'list-id', 'precedence', 'auto-submitted', 'content-type',
];
/** iCloud allows about 20 MB per message, and base64 makes files a third bigger. */
export const MAX_ATTACHMENTS_SIZE = 15 * 1024 * 1024;

export interface MailCredentials {
  address: string;
  loginName: string;
  password: string;
}

export class MailError extends Error {
  constructor(
    public code: EmailErrorCode,
    public detail?: string,
  ) {
    super(detail ?? code);
  }
}

const NETWORK_CODES = new Set(['ENOTFOUND', 'ECONNREFUSED', 'ETIMEDOUT', 'ECONNRESET', 'EAI_AGAIN', 'NoConnection', 'ETIMEOUT']);

function toMailError(error: unknown, whenRefused: EmailErrorCode): MailError {
  if (error instanceof MailError) return error;
  const value = error as { authenticationFailed?: boolean; code?: string; responseCode?: number; responseText?: string; response?: string; message?: string };
  if (value?.authenticationFailed || value?.code === 'EAUTH' || value?.responseCode === 535) return new MailError(whenRefused);
  if (value?.code && NETWORK_CODES.has(value.code)) return new MailError('network');
  return new MailError('server', value?.responseText ?? value?.response ?? value?.message);
}

function client(user: string, password: string) {
  return new ImapFlow({
    host: IMAP_HOST,
    port: 993,
    secure: true,
    auth: { user, pass: password },
    logger: false,
    connectionTimeout: 20_000,
    greetingTimeout: 15_000,
    socketTimeout: 60_000,
  });
}

/** One IMAP session: log in, do the work, log out; a refused login means the password no longer works. */
async function session<T>(credentials: MailCredentials, work: (imap: ImapFlow) => Promise<T>): Promise<T> {
  const imap = client(credentials.loginName, credentials.password);
  imap.on('error', () => {});
  try {
    await imap.connect();
  } catch (error) {
    throw toMailError(error, 'expired');
  }
  try {
    return await work(imap);
  } catch (error) {
    throw toMailError(error, 'server');
  } finally {
    await imap.logout().catch(() => imap.close());
  }
}

/**
 * Checks the address and password by logging in once. Apple asks for the whole address, though some accounts only take
 * the part before the @. Returns the user name that worked.
 */
export async function verifyLogin(address: string, password: string) {
  const names = [address, address.split('@')[0] ?? ''].filter((name, index, all) => name && all.indexOf(name) === index);
  for (const name of names) {
    const imap = client(name, password);
    imap.on('error', () => {});
    try {
      await imap.connect();
      await imap.logout().catch(() => imap.close());
      return name;
    } catch (error) {
      const mailError = toMailError(error, 'wrong_password');
      if (mailError.code !== 'wrong_password') throw mailError;
    }
  }
  throw new MailError('wrong_password');
}

function findFolder(folders: ListResponse[], specialUse: string, names: string[]) {
  return (
    folders.find((folder) => folder.specialUse === specialUse)?.path ??
    folders.find((folder) => names.some((name) => name.toLowerCase() === folder.path.toLowerCase()))?.path ??
    null
  );
}

async function folderOf(imap: ImapFlow, specialUse: string, names: string[], create: boolean) {
  const found = findFolder(await imap.list(), specialUse, names);
  if (found || !create) return found;
  // A new iCloud account has no Verzonden or bin until Mail first uses one: it gets iCloud's own name.
  await imap.mailboxCreate(names[0]!).catch(() => null);
  return names[0]!;
}

function addresses(value: AddressObject | AddressObject[] | undefined): EmailAddress[] {
  const list = Array.isArray(value) ? value : value ? [value] : [];
  return list.flatMap((entry) => entry.value).filter((entry) => entry.address).map((entry) => ({ name: entry.name || null, address: entry.address!.toLowerCase() }));
}

function references(parsed: ParsedMail) {
  const value = parsed.references;
  return Array.isArray(value) ? value : value ? value.split(/\s+/).filter(Boolean) : [];
}

/** The newest messages of the inbox and of Verzonden, headers only. */
export function recentMessages(credentials: MailCredentials) {
  const me = credentials.address.toLowerCase();
  return session(credentials, async (imap) => {
    const sent = await folderOf(imap, '\\Sent', SENT_NAMES, false);
    const messages: EmailMessage[] = [];
    for (const folder of [INBOX, sent].filter((name): name is string => Boolean(name))) {
      const isSent = folder === sent;
      const lock = await imap.getMailboxLock(folder, { readOnly: true });
      try {
        const box = imap.mailbox;
        const count = box ? box.exists : 0;
        if (!count) continue;
        const first = Math.max(1, count - (isSent ? RECENT_SENT : RECENT_INBOX) + 1);
        const rows = await imap.fetchAll(`${first}:*`, { uid: true, flags: true, internalDate: true, headers: HEADER_FIELDS });
        for (const row of rows) {
          if (!row.headers) continue;
          const parsed = await simpleParser(row.headers, { skipHtmlToText: true, skipTextToHtml: true, skipImageLinks: true });
          const from = addresses(parsed.from)[0] ?? { name: null, address: me };
          const isFromMe = isSent || from.address === me;
          const contentType = String(parsed.headers.get('content-type') && (parsed.headers.get('content-type') as { value?: string }).value || '');
          const internal = row.internalDate ? new Date(row.internalDate) : null;
          messages.push({
            id: `${folder}:${row.uid}`,
            ref: { folder, uid: row.uid },
            messageId: parsed.messageId ?? null,
            inReplyTo: parsed.inReplyTo ?? null,
            references: references(parsed),
            from,
            to: addresses(parsed.to),
            cc: addresses(parsed.cc),
            subject: parsed.subject ?? '',
            date: (parsed.date ?? internal ?? new Date(0)).toISOString(),
            isRead: isFromMe || Boolean(row.flags?.has('\\Seen')),
            isFromMe,
            hasAttachments: contentType.toLowerCase() === 'multipart/mixed',
            isAutomated: !isFromMe && isAutomatedMail(parsed.headers, from.address),
          });
        }
      } finally {
        lock.release();
      }
    }
    return messages;
  });
}

function byFolder(refs: EmailRef[]) {
  const groups = new Map<string, number[]>();
  for (const ref of refs) groups.set(ref.folder, [...(groups.get(ref.folder) ?? []), ref.uid]);
  return groups;
}

async function parsedMessages(imap: ImapFlow, folder: string, uids: number[]) {
  const lock = await imap.getMailboxLock(folder, { readOnly: true });
  try {
    const rows = await imap.fetchAll(uids, { uid: true, source: true }, { uid: true });
    const result: { uid: number; parsed: ParsedMail }[] = [];
    for (const row of rows) {
      if (row.source) result.push({ uid: row.uid, parsed: await simpleParser(row.source) });
    }
    return result;
  } finally {
    lock.release();
  }
}

function attachmentsOf(parsed: ParsedMail): EmailAttachment[] {
  return parsed.attachments
    .map((attachment, index) => ({ attachment, index }))
    // Pictures inside the HTML (a logo in a signature) are not files someone sent.
    .filter(({ attachment }) => attachment.contentDisposition !== 'inline' || !attachment.contentId)
    .map(({ attachment, index }) => ({
      index,
      name: attachment.filename || `Bijlage ${index + 1}`,
      mimeType: attachment.contentType,
      size: attachment.size,
    }));
}

function htmlToText(html: string) {
  return html
    .replace(/<(style|script)[\s\S]*?<\/\1>/gi, '')
    .replace(/<br\s*\/?>/gi, '\n')
    .replace(/<\/(p|div|li|tr|h\d)>/gi, '\n')
    .replace(/<[^>]+>/g, '')
    .replace(/&nbsp;/g, ' ')
    .replace(/&amp;/g, '&')
    .replace(/&lt;/g, '<')
    .replace(/&gt;/g, '>')
    .replace(/&quot;/g, '"')
    .replace(/&#39;/g, "'")
    .replace(/\n{3,}/g, '\n\n');
}

/** The messages with their text (only the new part) and their files. */
export function loadBodies(credentials: MailCredentials, refs: EmailRef[]) {
  return session(credentials, async (imap) => {
    const bodies: EmailMessageBody[] = [];
    for (const [folder, uids] of byFolder(refs)) {
      for (const { uid, parsed } of await parsedMessages(imap, folder, uids)) {
        const text = parsed.text ?? (typeof parsed.html === 'string' ? htmlToText(parsed.html) : '');
        bodies.push({ id: `${folder}:${uid}`, text: stripQuotedText(text), attachments: attachmentsOf(parsed) });
      }
    }
    return bodies;
  });
}

export function attachment(credentials: MailCredentials, ref: EmailRef, index: number) {
  return session(credentials, async (imap) => {
    const [found] = await parsedMessages(imap, ref.folder, [ref.uid]);
    const file = found?.parsed.attachments[index];
    if (!file) throw new MailError('not_found');
    return { name: file.filename || `Bijlage ${index + 1}`, mimeType: file.contentType, content: file.content };
  });
}

export function markRead(credentials: MailCredentials, refs: EmailRef[]) {
  return session(credentials, async (imap) => {
    for (const [folder, uids] of byFolder(refs)) {
      const lock = await imap.getMailboxLock(folder);
      try {
        await imap.messageFlagsAdd(uids, ['\\Seen'], { uid: true });
      } finally {
        lock.release();
      }
    }
  });
}

/** Always into the mailbox's own bin, as Mail does, so it can be brought back from there. */
export function trash(credentials: MailCredentials, refs: EmailRef[]) {
  return session(credentials, async (imap) => {
    const bin = await folderOf(imap, '\\Trash', TRASH_NAMES, true);
    if (!bin) throw new MailError('server', 'Er is geen prullenmand in je mailbox gevonden.');
    for (const [folder, uids] of byFolder(refs)) {
      if (folder === bin) continue;
      const lock = await imap.getMailboxLock(folder);
      try {
        await imap.messageMove(uids, bin, { uid: true });
      } finally {
        lock.release();
      }
    }
  });
}

export interface OutgoingMail {
  senderName: string | null;
  to: EmailAddress[];
  cc: EmailAddress[];
  subject: string;
  text: string;
  inReplyTo: string | null;
  references: string[];
  attachments: { name: string; mimeType: string; content: Buffer }[];
}

/** Sends over SMTP, then puts a copy in Verzonden, which over SMTP is up to the app. Not worth failing the send over. */
export async function send(credentials: MailCredentials, mail: OutgoingMail) {
  const composer = new MailComposer({
    from: { name: mail.senderName ?? '', address: credentials.address },
    to: mail.to.map((person) => ({ name: person.name ?? '', address: person.address })),
    cc: mail.cc.map((person) => ({ name: person.name ?? '', address: person.address })),
    subject: mail.subject,
    text: mail.text,
    inReplyTo: mail.inReplyTo ?? undefined,
    references: mail.references.length ? mail.references : undefined,
    attachments: mail.attachments.map((file) => ({ filename: file.name, contentType: file.mimeType, content: file.content })),
  });
  const message = composer.compile();
  message.keepBcc = false;
  const raw = await message.build();
  const messageId = message.messageId();

  const transport = nodemailer.createTransport({
    host: SMTP_HOST,
    port: 587,
    secure: false,
    requireTLS: true,
    auth: { user: credentials.address, pass: credentials.password },
    connectionTimeout: 20_000,
  });
  try {
    await transport.sendMail({
      envelope: { from: credentials.address, to: [...mail.to, ...mail.cc].map((person) => person.address) },
      raw,
    });
  } catch (error) {
    throw toMailError(error, 'expired');
  } finally {
    transport.close();
  }

  const sentProblem = await session(credentials, async (imap) => {
    const sent = await folderOf(imap, '\\Sent', SENT_NAMES, true);
    if (!sent) return 'geen map Verzonden gevonden';
    await imap.append(sent, raw, ['\\Seen']);
    return null;
  }).catch((error: MailError) => error.detail ?? error.code);
  return { messageId, sentProblem };
}
