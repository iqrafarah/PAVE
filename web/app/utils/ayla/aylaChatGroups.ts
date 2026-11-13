import type { Conversation } from '~/types/ayla';
import { AYLA_SECTION_TITLES } from './aylaMessages';
import { getChatSectionKind, readChatDate, type ChatSectionKind } from './aylaTimeline';

export interface ChatSection {
  kind: ChatSectionKind;
  title: string;
  conversations: Conversation[];
}

const SECTION_ORDER: ChatSectionKind[] = ['today', 'yesterday', 'lastWeek', 'lastMonth', 'earlier'];

function byNewest(first: string, second: string) {
  return second.localeCompare(first);
}

function sectionKind(conversation: Conversation, now: Date): ChatSectionKind {
  const updatedAt = readChatDate(conversation.updatedAt);
  return updatedAt ? getChatSectionKind(updatedAt, now) : 'earlier';
}

/**
 * Pinned chats first (the most recently pinned on top), then the rest by when they were last used, as on the iPhone
 * (AylaConversationList.sections). Empty groups are left out.
 */
export function groupConversations(conversations: Conversation[], now = new Date()): ChatSection[] {
  const pinned = conversations
    .filter((conversation) => conversation.pinnedAt)
    .sort((first, second) => byNewest(first.pinnedAt ?? '', second.pinnedAt ?? ''));
  const others = conversations
    .filter((conversation) => !conversation.pinnedAt)
    .sort((first, second) => byNewest(first.updatedAt, second.updatedAt));

  const sections: ChatSection[] = [];
  if (pinned.length) sections.push({ kind: 'pinned', title: AYLA_SECTION_TITLES.pinned, conversations: pinned });
  for (const kind of SECTION_ORDER) {
    const inSection = others.filter((conversation) => sectionKind(conversation, now) === kind);
    if (inSection.length) sections.push({ kind, title: AYLA_SECTION_TITLES[kind], conversations: inSection });
  }
  return sections;
}
