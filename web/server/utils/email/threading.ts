import type { EmailAddress, EmailMessage, EmailThread } from '#shared/types/email';

// Turns loose messages into conversations, and a full e-mail into the part worth showing as a chat bubble
// (iOS EmailThreading; keep the two the same).

const SUBJECT_PREFIXES = new Set(['re', 'aw', 'antw', 'antwoord', 'fw', 'fwd', 'wg', 'doorst', 'tr', 'sv', 'vs']);
const FORWARD_PREFIXES = new Set(['fw', 'fwd', 'wg', 'doorst', 'tr']);
const MACHINES = ['noreply', 'no-reply', 'donotreply', 'do-not-reply', 'mailer-daemon', 'notifications', 'notification', 'newsletter', 'nieuwsbrief'];

/** "Re: RE: Fwd: Stage" becomes "Stage". */
export function normalizedSubject(subject: string) {
  let value = subject.trim();
  let changed = true;
  while (changed) {
    changed = false;
    const close = value.indexOf(']');
    if (value.startsWith('[') && close > 0 && close < 20) {
      value = value.slice(close + 1).trim();
      changed = true;
    }
    const colon = value.indexOf(':');
    if (colon < 0) break;
    const prefix = value.slice(0, colon).toLowerCase().trim().replace(/\[\d+\]$/, '');
    if (SUBJECT_PREFIXES.has(prefix)) {
      value = value.slice(colon + 1).trim();
      changed = true;
    }
  }
  return value;
}

/** "Fwd: Stage", also as "Re: Fwd: Stage". */
export function isForward(subject: string) {
  let value = subject.trim();
  let colon = value.indexOf(':');
  while (colon >= 0 && colon <= 8) {
    const prefix = value.slice(0, colon).toLowerCase().trim();
    if (FORWARD_PREFIXES.has(prefix)) return true;
    if (!SUBJECT_PREFIXES.has(prefix)) return false;
    value = value.slice(colon + 1).trim();
    colon = value.indexOf(':');
  }
  return false;
}

export function normalizedId(id: string) {
  return id.replace(/^[<>\s]+|[<>\s]+$/g, '').toLowerCase();
}

export function replySubject(subject: string) {
  const clean = normalizedSubject(subject);
  return clean ? `Re: ${clean}` : 'Re:';
}

/** A newsletter, notification or other mail no person wrote. */
export function isAutomatedMail(headers: Map<string, unknown>, from: string) {
  if (headers.has('list-unsubscribe') || headers.has('list-id')) return true;
  const precedence = String(headers.get('precedence') ?? '').toLowerCase();
  if (['bulk', 'list', 'junk'].includes(precedence)) return true;
  const auto = headers.get('auto-submitted');
  if (auto !== undefined && String(auto).toLowerCase() !== 'no') return true;
  const sender = from.toLowerCase().split('@')[0] ?? '';
  return MACHINES.includes(sender) || sender.startsWith('noreply') || sender.startsWith('no-reply');
}

function counterparts(message: EmailMessage) {
  return (message.isFromMe ? [...message.to, ...message.cc] : [message.from]).map((person) => person.address.toLowerCase());
}

/**
 * The Message-ID, In-Reply-To and References headers link messages; messages without those headers join a conversation
 * with the same subject and person. Newest conversation first, each oldest message first.
 */
export function threadsOf(messages: EmailMessage[]): EmailThread[] {
  const parent = messages.map((_, index) => index);
  const root = (index: number): number => {
    while (parent[index] !== index) {
      parent[index] = parent[parent[index]!]!;
      index = parent[index]!;
    }
    return index;
  };
  const join = (a: number, b: number) => {
    const ra = root(a);
    const rb = root(b);
    if (ra !== rb) parent[rb] = ra;
  };

  const byMessageId = new Map<string, number>();
  messages.forEach((message, index) => {
    const ids = [message.messageId, message.inReplyTo, ...message.references].filter((id): id is string => Boolean(id)).map(normalizedId);
    for (const id of ids) {
      if (!id) continue;
      const other = byMessageId.get(id);
      if (other === undefined) byMessageId.set(id, index);
      else join(other, index);
    }
  });

  const bySubject = new Map<string, number>();
  messages.forEach((message, index) => {
    const subject = normalizedSubject(message.subject).toLowerCase();
    // A forward starts a conversation of its own: only its headers (an answer to it) join it to anything.
    if (!subject || isForward(message.subject)) return;
    for (const person of counterparts(message)) {
      const key = `${subject}\u0000${person}`;
      const other = bySubject.get(key);
      if (other === undefined) bySubject.set(key, index);
      else join(other, index);
    }
  });

  const groups = new Map<number, EmailMessage[]>();
  messages.forEach((message, index) => {
    const key = root(index);
    groups.set(key, [...(groups.get(key) ?? []), message]);
  });
  return [...groups.values()]
    .map((items) => {
      const sorted = items.sort((a, b) => a.date.localeCompare(b.date));
      const first = sorted[0]!;
      return { id: `icloud:${first.messageId ? normalizedId(first.messageId) : first.id}`, messages: sorted };
    })
    .sort((a, b) => b.messages.at(-1)!.date.localeCompare(a.messages.at(-1)!.date));
}

/** The people you have written to: everyone on the mail you sent, most recent first. */
export function knownPeople(messages: EmailMessage[], me: string): EmailAddress[] {
  const seen = new Set([me.toLowerCase()]);
  const people: EmailAddress[] = [];
  for (const message of [...messages].sort((a, b) => b.date.localeCompare(a.date))) {
    if (!message.isFromMe) continue;
    for (const person of [...message.to, ...message.cc]) {
      const key = person.address.toLowerCase();
      if (seen.has(key)) continue;
      seen.add(key);
      people.push(person);
    }
  }
  return people;
}

/** A real conversation: you wrote in it, or someone you wrote to did, and it is not only newsletters and automatic notices. */
export function isConversation(thread: EmailThread, known: Set<string>) {
  if (thread.messages.some((message) => message.isFromMe)) return true;
  return thread.messages.some((message) => !message.isAutomated && known.has(message.from.address.toLowerCase()));
}

const ATTRIBUTION_PATTERNS = [
  /^(op|on|le|am|el)\s.+(schreef|wrote|a écrit|schrieb|escribió).*:\s*$/,
  /^.+\sheeft\s.+geschreven\s*:\s*$/,
  /^-{2,}\s*(original message|oorspronkelijk bericht|oorspronkelijk e-?mailbericht|forwarded message|doorgestuurd bericht)\s*-{2,}\s*$/,
  /^_{10,}\s*$/,
];

/** Everything the sender wrote, without the history the mail program quotes below it. */
export function stripQuotedText(text: string) {
  const lines = text.replace(/\r\n/g, '\n').split('\n');
  let cut = lines.length;
  for (let index = 0; index < lines.length; index++) {
    const trimmed = lines[index]!.trim();
    const lowered = trimmed.toLowerCase();
    if (trimmed.startsWith('>')) {
      // A quote only ends the message when nothing of the sender's own follows it.
      const rest = lines.slice(index).filter((line) => line.trim());
      if (rest.every((line) => line.trim().startsWith('>'))) {
        cut = index;
        break;
      }
      continue;
    }
    if (ATTRIBUTION_PATTERNS.some((pattern) => pattern.test(lowered))) {
      cut = index;
      break;
    }
    const next = lines[index + 1]?.toLowerCase().trim();
    if ((lowered.startsWith('op ') || lowered.startsWith('on ')) && next !== undefined && ATTRIBUTION_PATTERNS[0]!.test(`${lowered} ${next}`)) {
      cut = index;
      break;
    }
    // Outlook's header block: "Van: …" followed by "Verzonden:" or "Sent:".
    if (lowered.startsWith('van:') || lowered.startsWith('from:')) {
      const following = lines.slice(index + 1, index + 4).map((line) => line.toLowerCase().trim());
      if (following.some((line) => ['verzonden:', 'sent:', 'datum:', 'date:'].some((key) => line.startsWith(key)))) {
        cut = index;
        break;
      }
    }
  }
  const kept = lines.slice(0, cut).join('\n').trim();
  return kept || text.trim();
}
