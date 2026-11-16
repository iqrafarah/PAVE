import type { AylaAttachment } from '~/types/ayla';
import { AYLA_FILE_EMPTY, AYLA_FILE_TOO_LONG, AYLA_FILE_TYPE_UNSUPPORTED } from './aylaMessages';

export const MAX_ATTACHMENTS = 3;
export const MAX_ATTACHMENT_LENGTH = 20000;
export const MAX_ATTACHMENT_NAME_LENGTH = 200;
export const READABLE_FILE_EXTENSIONS = ['.txt', '.md', '.csv'];
export const ATTACHMENT_ACCEPT = READABLE_FILE_EXTENSIONS.join(',');

function hasReadableExtension(fileName: string) {
  const lowerName = fileName.toLowerCase();
  return READABLE_FILE_EXTENSIONS.some((extension) => lowerName.endsWith(extension));
}

/** Reads the text of a file in the browser. Only the text is ever sent to Ayla, never the file. */
export async function readAttachment(
  file: File,
): Promise<{ attachment: AylaAttachment | null; error: string | null }> {
  if (!hasReadableExtension(file.name)) return { attachment: null, error: AYLA_FILE_TYPE_UNSUPPORTED };

  const text = (await file.text()).trim();
  if (!text) return { attachment: null, error: AYLA_FILE_EMPTY };
  if (text.length > MAX_ATTACHMENT_LENGTH) return { attachment: null, error: AYLA_FILE_TOO_LONG };

  const name = file.name.slice(0, MAX_ATTACHMENT_NAME_LENGTH);
  return { attachment: { name, text }, error: null };
}
