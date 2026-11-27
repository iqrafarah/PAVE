import { asEmailError, credentialsOf, emailError } from '../../utils/email/account';
import { attachment } from '../../utils/email/mailbox';
import { isRef } from '../../utils/email/request';

// One file of a message, to open or save; never cached.
export default defineEventHandler(async (event) => {
  try {
    const query = getQuery(event);
    const ref = { folder: String(query.folder ?? ''), uid: Number(query.uid) };
    const index = Number(query.index);
    if (!isRef(ref) || !Number.isInteger(index) || index < 0) throw emailError('invalid');
    const file = await attachment(await credentialsOf(event), ref, index);
    setResponseHeaders(event, {
      'content-type': file.mimeType || 'application/octet-stream',
      'content-disposition': `attachment; filename*=UTF-8''${encodeURIComponent(file.name)}`,
      'cache-control': 'private, no-store',
      'x-content-type-options': 'nosniff',
    });
    return file.content;
  } catch (error) {
    throw asEmailError(error);
  }
});
