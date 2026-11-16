import type { AylaBlock, AylaReply, ChatMessage, MemoryCategory } from '~/types/ayla';

const KNOWN_BLOCK_TYPES = ['vaultSelection', 'vacancies', 'skillSuggestions', 'cv'];
const MEMORY_CATEGORY_IDS: MemoryCategory[] = [
  'education',
  'work',
  'goals',
  'skills',
  'values',
  'workStyle',
  'interests',
  'personal',
];

function isObject(value: unknown): value is Record<string, unknown> {
  return typeof value === 'object' && value !== null;
}

function isKnownBlock(block: unknown): block is AylaBlock {
  return isObject(block) && KNOWN_BLOCK_TYPES.includes(String(block.type));
}

/** An unknown category becomes 'personal', as on the server and iOS. */
export function toMemoryCategory(value: unknown): MemoryCategory {
  const category = MEMORY_CATEGORY_IDS.find((id) => id === value);
  return category ?? 'personal';
}

/** Reads a reply from the server or from ayla_messages.reply; returns null when it is not a reply. */
export function parseReply(value: unknown): AylaReply | null {
  if (!isObject(value) || typeof value.text !== 'string') return null;

  const reply = value as unknown as AylaReply;
  const blocks = Array.isArray(value.blocks) ? value.blocks.filter(isKnownBlock) : [];
  return { ...reply, blocks, usedData: Array.isArray(value.usedData) ? reply.usedData : [] };
}

export function createMessage(role: ChatMessage['role'], text: string): ChatMessage {
  return {
    id: crypto.randomUUID(),
    role,
    text,
    reply: null,
    createdAt: new Date().toISOString(),
    isWriting: false,
    attachmentNames: [],
  };
}

export function getVacancyBlocks(reply: AylaReply | null) {
  // An older or incomplete reply may come without blocks.
  if (!reply?.blocks) return [];
  return reply.blocks.filter((block) => block.type === 'vacancies');
}
