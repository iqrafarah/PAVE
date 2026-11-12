// What was fetched last, kept for a quick start: after a refresh the vault, the chats and what Ayla remembers show at
// once from this copy, and are then checked against the database in the background.
//
// It is kept per tab (session storage): it survives a refresh, and is gone when the tab closes or you sign out. That
// keeps evidence and chat titles from lying around on a shared computer. Each copy belongs to one account and is never
// shown to another.

const PREFIX = 'pave-kept:';

interface Kept<T> {
  userId: string;
  data: T;
}

export function readKept<T>(name: string, userId: string | undefined): T | null {
  if (!import.meta.client || !userId) return null;
  try {
    const kept = JSON.parse(sessionStorage.getItem(PREFIX + name) ?? 'null') as Kept<T> | null;
    return kept?.userId === userId ? kept.data : null;
  } catch {
    return null;
  }
}

export function writeKept<T>(name: string, userId: string | undefined, data: T) {
  if (!import.meta.client || !userId) return;
  try {
    sessionStorage.setItem(PREFIX + name, JSON.stringify({ userId, data } satisfies Kept<T>));
  } catch {
    // Storage is full or blocked: the next start simply reads from the database.
  }
}

export function clearKept() {
  if (!import.meta.client) return;
  try {
    for (const key of Object.keys(sessionStorage)) {
      if (key.startsWith(PREFIX)) sessionStorage.removeItem(key);
    }
  } catch {
    // Nothing was kept either.
  }
}
