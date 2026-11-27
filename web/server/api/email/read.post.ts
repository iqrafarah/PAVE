import { asEmailError, credentialsOf } from '../../utils/email/account';
import { markRead } from '../../utils/email/mailbox';
import { readRefs } from '../../utils/email/request';

// Opening a conversation marks it read in the mailbox too, so Mail on the Mac agrees.
export default defineEventHandler(async (event) => {
  try {
    const refs = await readRefs(event);
    await markRead(await credentialsOf(event), refs);
    return { ok: true };
  } catch (error) {
    throw asEmailError(error);
  }
});
