import type { Conversation } from '~/types/ayla';

/** Pinned chats ("Vastgezet") and all other chats ("Chats"), newest first, as in the Figma chat history. */
export function splitPinned(conversations: Conversation[]) {
  const pinned = conversations.filter((conversation) => conversation.pinnedAt);
  const others = conversations.filter((conversation) => !conversation.pinnedAt);
  return { pinned, others };
}
