import type { EmailAddress, EmailErrorCode, EmailMessage, EmailThread } from '#shared/types/email';
import type { PaveNotification } from '~/types/notifications';
import { EMAIL_ERRORS, EMAIL_NO_SUBJECT, EMAIL_TODAY, EMAIL_YESTERDAY, EMAIL_YOU } from './emailMessages';

// E-mail conversations in Meldingen (iOS EmailThread and EmailReplyRecipients; keep the two the same).

const SUBJECT_PREFIX = /^\s*((re|aw|antw|antwoord|fw|fwd|wg|doorst|tr|sv|vs)(\[\d+\])?\s*:\s*)+/i;
const ICLOUD_DOMAINS = ['icloud.com', 'me.com', 'mac.com'];
const MICROSOFT_DOMAINS = ['hotmail.com', 'hotmail.nl', 'outlook.com', 'outlook.nl', 'live.com', 'live.nl', 'msn.com'];
/** The id of an e-mail row in Meldingen: "mail:" and the conversation. */
export const EMAIL_ENTRY_PREFIX = 'mail:';

/** The name if there is one, otherwise the part before the @. */
export function displayName(person: EmailAddress) {
  return person.name?.trim() || person.address.split('@')[0] || person.address;
}

/** Without "Re:" and the like; empty when the mail has no subject. */
export function threadSubject(thread: EmailThread) {
  return (thread.messages[0]?.subject ?? '').replace(SUBJECT_PREFIX, '').trim();
}

export function latestMessage(thread: EmailThread) {
  return thread.messages.at(-1) ?? null;
}

export function isThreadUnread(thread: EmailThread) {
  return thread.messages.some((message) => !message.isRead && !message.isFromMe);
}

/** The people you write with, without yourself, the most recent first. */
export function participants(thread: EmailThread) {
  const seen = new Set(thread.messages.filter((message) => message.isFromMe).map((message) => message.from.address.toLowerCase()));
  const result: EmailAddress[] = [];
  for (const message of [...thread.messages].reverse()) {
    const others = message.isFromMe ? [...message.to, ...message.cc] : [message.from];
    for (const person of others) {
      const key = person.address.toLowerCase();
      if (seen.has(key)) continue;
      seen.add(key);
      result.push(person);
    }
  }
  return result;
}

/** "Iqra, Ravi": two people with the same name are told apart by their address. */
export function participantNames(thread: EmailThread) {
  const people = participants(thread).slice(0, 3);
  const names = people.map(displayName);
  const labels = people.map((person, index) => (names.filter((name) => name === names[index]).length > 1 ? person.address : names[index]));
  return labels.length ? labels.join(', ') : EMAIL_YOU;
}

/** An e-mail conversation as a row of Meldingen, so the list, the filters and the search treat it like a notification. */
export function threadAsNotification(thread: EmailThread): PaveNotification {
  const latest = latestMessage(thread);
  return {
    id: `${EMAIL_ENTRY_PREFIX}${thread.id}`,
    kind: 'email',
    title: participantNames(thread),
    personName: threadSubject(thread) || EMAIL_NO_SUBJECT,
    date: latest?.date ?? new Date(0).toISOString(),
    isUnread: isThreadUnread(thread),
    deletedAt: null,
    conversationId: null,
    validationRequestId: null,
    vaultItemId: null,
    learnerName: null,
    learnerOrganization: null,
    documentName: null,
    documentType: null,
    emailThreadId: thread.id,
  };
}

export function isEmailEntryId(id: string) {
  return id.startsWith(EMAIL_ENTRY_PREFIX);
}

export function threadIdOf(entryId: string) {
  return entryId.slice(EMAIL_ENTRY_PREFIX.length);
}

/** Who a reply goes to: everyone who was on the message, minus yourself, or only the person who wrote it. */
export function replyRecipients(message: EmailMessage, me: string, everyone: boolean) {
  const mine = me.toLowerCase();
  if (!everyone) {
    const person = message.isFromMe ? message.to.find((entry) => entry.address.toLowerCase() !== mine) : message.from;
    return { to: person ? [person] : [], cc: [] as EmailAddress[] };
  }
  const seen = new Set([mine]);
  const unique = (people: EmailAddress[]) =>
    people.filter((person) => {
      const key = person.address.toLowerCase();
      if (seen.has(key)) return false;
      seen.add(key);
      return true;
    });
  const to = unique(message.isFromMe ? message.to : [message.from, ...message.to]);
  const cc = unique(message.cc);
  return { to, cc };
}

export function replySubject(subject: string) {
  const clean = subject.replace(SUBJECT_PREFIX, '').trim();
  return clean ? `Re: ${clean}` : 'Re:';
}

/** "Vandaag 21:59", "Gisteren 14:02", otherwise the date and time. */
export function messageTime(isoDate: string, now = new Date()) {
  const date = new Date(isoDate);
  const time = date.toLocaleTimeString('nl-NL', { hour: '2-digit', minute: '2-digit' });
  const startOf = (value: Date) => new Date(value.getFullYear(), value.getMonth(), value.getDate()).getTime();
  const days = Math.round((startOf(now) - startOf(date)) / 86_400_000);
  if (days <= 0) return EMAIL_TODAY(time);
  if (days === 1) return EMAIL_YESTERDAY(time);
  return `${date.toLocaleDateString('nl-NL', { day: 'numeric', month: 'short', year: date.getFullYear() === now.getFullYear() ? undefined : 'numeric' })} ${time}`;
}

export function fileSize(bytes: number) {
  if (bytes < 1024) return `${bytes} B`;
  if (bytes < 1024 * 1024) return `${Math.round(bytes / 1024)} kB`;
  return `${(bytes / 1024 / 1024).toFixed(1).replace('.', ',')} MB`;
}

/** Why this address cannot be an iCloud Mail address, or null when it can. */
export function addressProblem(address: string) {
  const domain = address.trim().toLowerCase().split('@')[1];
  if (!domain) return null;
  if (MICROSOFT_DOMAINS.includes(domain)) return 'outlook' as const;
  return ICLOUD_DOMAINS.includes(domain) ? null : ('other' as const);
}

/** "a@b.nl, Iqra <iqra@icloud.com>" as people; null when one of them is not an address. */
export function parseRecipients(text: string, known: EmailAddress[]): EmailAddress[] | null {
  const parts = text.split(/[,;]/).map((part) => part.trim()).filter(Boolean);
  const people: EmailAddress[] = [];
  for (const part of parts) {
    const match = part.match(/^(.*)<([^<>]+)>$/);
    const address = (match ? match[2]! : part).trim().toLowerCase();
    if (!/^[^@\s<>]+@[^@\s<>]+\.[^@\s<>]+$/.test(address)) return null;
    const name = match?.[1]?.trim().replace(/^"|"$/g, '') || known.find((person) => person.address === address)?.name || null;
    if (!people.some((person) => person.address === address)) people.push({ name, address });
  }
  return people;
}

/** The error code from a failed call to /api/email, in words. */
export function emailErrorMessage(error: unknown, fallback: string) {
  const data = (error as { data?: { data?: { code?: string }; statusMessage?: string } })?.data;
  const code = (data?.data?.code ?? data?.statusMessage) as EmailErrorCode | undefined;
  return (code && EMAIL_ERRORS[code]) || fallback;
}

export function emailErrorCode(error: unknown) {
  const data = (error as { data?: { data?: { code?: string }; statusMessage?: string } })?.data;
  return (data?.data?.code ?? data?.statusMessage ?? null) as EmailErrorCode | null;
}
