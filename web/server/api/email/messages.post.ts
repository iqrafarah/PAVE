import { asEmailError, credentialsOf } from '../../utils/email/account';
import { loadBodies } from '../../utils/email/mailbox';
import { readRefs } from '../../utils/email/request';

// The text and the files of the messages of an opened conversation.
export default defineEventHandler(async (event) => {
  try {
    const refs = await readRefs(event);
    return await loadBodies(await credentialsOf(event), refs);
  } catch (error) {
    throw asEmailError(error);
  }
});
