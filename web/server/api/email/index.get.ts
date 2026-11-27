import type { EmailOverview } from '#shared/types/email';
import { asEmailError, connectedAccount, credentialsOf } from '../../utils/email/account';
import { recentMessages } from '../../utils/email/mailbox';
import { isConversation, knownPeople, threadsOf } from '../../utils/email/threading';

// Meldingen › e-mail: the connected account and its conversations, only with people you wrote to, without newsletters
// and automatic mail (iOS EmailModel.visibleThreads). Headers only; the text comes when a conversation opens.
export default defineEventHandler(async (event): Promise<EmailOverview> => {
  try {
    const row = await connectedAccount(event);
    if (!row) return { account: null, threads: [], people: [] };
    const credentials = await credentialsOf(event);
    const messages = await recentMessages(credentials);
    const people = knownPeople(messages, credentials.address);
    const known = new Set(people.map((person) => person.address));
    const threads = threadsOf(messages).filter((thread) => isConversation(thread, known));
    return { account: { address: row.address }, threads, people };
  } catch (error) {
    throw asEmailError(error);
  }
});
