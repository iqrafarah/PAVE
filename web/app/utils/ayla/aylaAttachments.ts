import { toRaw } from 'vue';
import type { AylaAttachment } from '~/types/ayla';
import { AYLA_FILE_EMPTY, AYLA_FILE_TOO_LONG, AYLA_FILE_TYPE_UNSUPPORTED } from './aylaMessages';
import { isPdf, readPdf, readPhoto } from '~/utils/vault/vaultSkillsMaterial';

export const MAX_ATTACHMENTS = 5;
export const MAX_ATTACHMENT_IMAGES = 4;
export const MAX_ATTACHMENT_LENGTH = 20000;
export const MAX_ATTACHMENT_NAME_LENGTH = 200;
export const READABLE_FILE_EXTENSIONS = ['.txt', '.md', '.csv', '.pdf'];
export const IMAGE_FILE_EXTENSIONS = ['.jpg', '.jpeg', '.png', '.webp', '.gif'];
export const ATTACHMENT_ACCEPT = [...READABLE_FILE_EXTENSIONS, ...IMAGE_FILE_EXTENSIONS].join(',');
export const PHOTO_ACCEPT = 'image/*';
/** What a photo without readable text says (iOS AylaAttachment.photoWithoutText); Ayla then looks at the photo itself. */
export const PHOTO_WITHOUT_TEXT = '(foto zonder leesbare tekst)';

// The photo Ayla looks at is small enough for the request (the function refuses above 1.4 million characters).
const PHOTO_SIDE = 1024;

// The files stay in this browser: only their text and small photos are sent. They are kept here, next to what was sent,
// so "Zet in de kluis" can take the same files along (iOS AylaChatFile.upload).
const files = new WeakMap<AylaAttachment, File>();

/** The file behind an attachment. Vue keeps the chat's attachments as reactive copies: the lookup uses the original. */
export function fileOfAttachment(attachment: AylaAttachment) {
  return files.get(toRaw(attachment)) ?? null;
}

function hasExtension(fileName: string, extensions: string[]) {
  const lowerName = fileName.toLowerCase();
  return extensions.some((extension) => lowerName.endsWith(extension));
}

function isPicture(file: File) {
  return file.type.startsWith('image/') || hasExtension(file.name, IMAGE_FILE_EXTENSIONS);
}

/** Reads the text of a file in the browser. Only the text (and a small photo) is ever sent to Ayla, never the file. */
export async function readAttachment(
  file: File,
  { imagesSoFar = 0 }: { imagesSoFar?: number } = {},
): Promise<{ attachment: AylaAttachment | null; error: string | null }> {
  const name = file.name.slice(0, MAX_ATTACHMENT_NAME_LENGTH);
  let text = '';
  let image: string | undefined;

  if (isPdf(file)) {
    const read = await readPdf(file, { side: PHOTO_SIDE });
    text = read?.text?.trim() ?? '';
    // A scan has no text: its first page goes along as a photo instead.
    if (!text && read?.photo && imagesSoFar < MAX_ATTACHMENT_IMAGES) {
      image = read.photo;
      text = PHOTO_WITHOUT_TEXT;
    }
  } else if (isPicture(file)) {
    // A photo goes along as a small image, so Ayla looks at it herself. The browser cannot read its text.
    const photo = imagesSoFar < MAX_ATTACHMENT_IMAGES ? await readPhoto(file, PHOTO_SIDE) : null;
    if (!photo) return { attachment: null, error: AYLA_FILE_TYPE_UNSUPPORTED };
    image = photo;
    text = PHOTO_WITHOUT_TEXT;
  } else if (hasExtension(file.name, READABLE_FILE_EXTENSIONS) || file.type.startsWith('text/')) {
    text = (await file.text()).trim();
  } else {
    return { attachment: null, error: AYLA_FILE_TYPE_UNSUPPORTED };
  }

  if (!text) return { attachment: null, error: AYLA_FILE_EMPTY };
  if (text.length > MAX_ATTACHMENT_LENGTH) return { attachment: null, error: AYLA_FILE_TOO_LONG };

  const attachment: AylaAttachment = { name, text, ...(image ? { image } : {}) };
  files.set(attachment, file);
  return { attachment, error: null };
}

// The files sent in each chat, kept in this browser (iOS keeps them with the chat on the device), so "Ja" to putting it
// in the vault still has them after the app moved to /ayla/<id>, after a refresh, or when you come back to the chat
// later. They stay in IndexedDB on this device only; nothing of them goes anywhere until you save them in the vault.
// A new chat has no id yet: its files move to the id once the chat exists.
const NEW_CHAT = '';
/** As many as one vault item takes. */
const MAX_CHAT_FILES = 5;
const DATABASE = 'pave-chat-files';
const STORE = 'files';
// Per chat: every file sent in it, and the ones sent with the latest message that had files. "Ja" to putting something
// in the vault takes the latest ones (the photo Ayla just looked at), not a file from an earlier subject in the chat.
interface ChatFiles {
  files: File[];
  last: File[];
}
const chatFiles = new Map<string, ChatFiles>();

function openDatabase() {
  return new Promise<IDBDatabase | null>((resolve) => {
    try {
      const request = indexedDB.open(DATABASE, 1);
      request.onupgradeneeded = () => request.result.createObjectStore(STORE);
      request.onsuccess = () => resolve(request.result);
      request.onerror = () => resolve(null);
    } catch {
      resolve(null);
    }
  });
}

/** Reads or writes one chat's files; without storage (private window, blocked) it quietly does nothing. */
async function withStore<T>(mode: IDBTransactionMode, use: (store: IDBObjectStore) => IDBRequest<T>) {
  const database = await openDatabase();
  if (!database) return null;
  return new Promise<T | null>((resolve) => {
    try {
      const request = use(database.transaction(STORE, mode).objectStore(STORE));
      request.onsuccess = () => resolve(request.result);
      request.onerror = () => resolve(null);
    } catch {
      resolve(null);
    } finally {
      database.close();
    }
  });
}

function store(key: string, entry: ChatFiles) {
  chatFiles.set(key, entry);
  if (key !== NEW_CHAT) withStore('readwrite', (objects) => objects.put(entry, key));
}

async function entryOf(conversationId: string | null): Promise<ChatFiles> {
  const key = conversationId ?? NEW_CHAT;
  const known = chatFiles.get(key);
  if (known || key === NEW_CHAT) return known ?? { files: [], last: [] };
  const saved = await withStore<ChatFiles | File[] | undefined>('readonly', (objects) => objects.get(key));
  // Kept by an earlier version as a plain list.
  const entry = Array.isArray(saved) ? { files: saved, last: saved } : (saved ?? { files: [], last: [] });
  chatFiles.set(key, entry);
  return entry;
}

/** The files sent with one message. */
export function rememberChatFiles(conversationId: string | null, files: File[]) {
  if (!files.length) return;
  const key = conversationId ?? NEW_CHAT;
  const known = chatFiles.get(key)?.files ?? [];
  store(key, { files: [...known, ...files.filter((file) => !known.includes(file))].slice(-MAX_CHAT_FILES), last: files.slice(-MAX_CHAT_FILES) });
}

/** Every file sent in the chat. */
export async function chatFilesOf(conversationId: string | null) {
  return (await entryOf(conversationId)).files;
}

/** The files of the latest message that had files: what Ayla is talking about now. */
export async function latestChatFiles(conversationId: string | null) {
  return (await entryOf(conversationId)).last;
}

/** The latest files went into the vault: they no longer go along with the next questions, a next item starts clean. */
export async function clearLatestChatFiles(conversationId: string | null) {
  const key = conversationId ?? NEW_CHAT;
  const entry = await entryOf(conversationId);
  store(key, { files: entry.files, last: [] });
}

export function moveNewChatFiles(conversationId: string) {
  const entry = chatFiles.get(NEW_CHAT);
  if (!entry) return;
  chatFiles.delete(NEW_CHAT);
  store(conversationId, entry);
}

/** A deleted chat: its files are no longer kept on this device. */
export function forgetChatFiles(conversationId: string) {
  chatFiles.delete(conversationId);
  withStore('readwrite', (objects) => objects.delete(conversationId));
}

export function forgetNewChatFiles() {
  chatFiles.delete(NEW_CHAT);
}

const readFiles = new WeakMap<File, AylaAttachment | null>();

/**
 * The files of the latest message with files in this chat, read again for Ayla (each file once per visit), so a later question still comes
 * with them: she looks at the photo again instead of asking for it. At most as many as one message takes.
 */
export async function chatAttachmentsOf(conversationId: string | null) {
  const attachments: AylaAttachment[] = [];
  let images = 0;
  for (const file of (await latestChatFiles(conversationId)).slice(-MAX_ATTACHMENTS)) {
    if (!readFiles.has(file)) readFiles.set(file, (await readAttachment(file, { imagesSoFar: 0 }).catch(() => null))?.attachment ?? null);
    const attachment = readFiles.get(file);
    if (!attachment) continue;
    if (attachment.image) {
      if (images >= MAX_ATTACHMENT_IMAGES) continue;
      images += 1;
    }
    attachments.push(attachment);
  }
  return attachments;
}
