const DRAFT_KEY_PREFIX = 'ayla-draft:';
const NEW_CHAT_KEY = 'new';

function getKey(conversationId: string | null) {
  return `${DRAFT_KEY_PREFIX}${conversationId ?? NEW_CHAT_KEY}`;
}

/** A half-typed message, kept per chat in this browser tab. Storage can be blocked, so it may silently do nothing. */
export function useAylaDraft() {
  function readDraft(conversationId: string | null) {
    try {
      return sessionStorage.getItem(getKey(conversationId)) ?? '';
    } catch {
      return '';
    }
  }

  function saveDraft(conversationId: string | null, text: string) {
    try {
      if (text) sessionStorage.setItem(getKey(conversationId), text);
      else sessionStorage.removeItem(getKey(conversationId));
    } catch {
      // Storage is blocked (private window, settings): the draft is simply not kept.
    }
  }

  return { readDraft, saveDraft };
}
