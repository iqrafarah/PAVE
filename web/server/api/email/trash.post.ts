import { asEmailError, credentialsOf } from '../../utils/email/account';
import { trash } from '../../utils/email/mailbox';
import { readRefs } from '../../utils/email/request';

// Deleting moves the messages to the bin of the iCloud mailbox; Mail can still bring them back.
export default defineEventHandler(async (event) => {
  try {
    const refs = await readRefs(event);
    await trash(await credentialsOf(event), refs);
    return { ok: true };
  } catch (error) {
    throw asEmailError(error);
  }
});
