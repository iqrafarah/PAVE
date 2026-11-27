// E-mail in Meldingen (iOS Features/Notifications/Email): the learner's own iCloud Mail, read and sent by PAVE's web
// server, shown as chats. Shared by the browser (app/) and the server routes (server/api/email).

export interface EmailAddress {
  name: string | null;
  address: string;
}

/** The connected mailbox; the password never leaves the server. */
export interface EmailAccount {
  address: string;
}

/** Where a message sits in the mailbox: an IMAP folder and its UID there. */
export interface EmailRef {
  folder: string;
  uid: number;
}

export interface EmailAttachment {
  /** Its place among the message's attachments, for downloading it. */
  index: number;
  name: string;
  mimeType: string;
  size: number;
}

export interface EmailMessage {
  /** "folder:uid". */
  id: string;
  ref: EmailRef;
  messageId: string | null;
  inReplyTo: string | null;
  references: string[];
  from: EmailAddress;
  to: EmailAddress[];
  cc: EmailAddress[];
  subject: string;
  /** ISO date. */
  date: string;
  isRead: boolean;
  isFromMe: boolean;
  hasAttachments: boolean;
  isAutomated: boolean;
}

/** A message with its text: only the new part, without the quoted history, so it reads like a chat bubble. */
export interface EmailMessageBody {
  id: string;
  text: string;
  attachments: EmailAttachment[];
}

export interface EmailThread {
  id: string;
  /** Oldest first. */
  messages: EmailMessage[];
}

export interface EmailOverview {
  account: EmailAccount | null;
  threads: EmailThread[];
  /** Everyone you have written to, for the suggestions in "Aan". */
  people: EmailAddress[];
}

/** Why the server could not do it; the browser turns it into Dutch (iOS EmailError). */
export type EmailErrorCode =
  | 'not_signed_in'
  | 'not_configured'
  | 'not_connected'
  | 'not_icloud'
  | 'wrong_password'
  | 'expired'
  | 'network'
  | 'server'
  | 'too_large'
  | 'invalid'
  | 'not_found';
