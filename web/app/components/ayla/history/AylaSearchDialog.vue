<script setup lang="ts">
import type { Conversation } from '~/types/ayla';
import type { VaultFile } from '~/types/vault';

// Search over everything in PAVE, like ChatGPT's: a large field on top, tabs under it, and one row per result with an
// icon, the title (the words you typed in bold), a line under it and when it was last changed. Chats (with a piece of the
// message that holds the words), evidence, documents and pictures in the vault, and chats inside a project.
type Tab = 'all' | 'chats' | 'items' | 'documents' | 'images' | 'projects';
interface Result {
  key: string;
  kind: 'chat' | 'item' | 'file';
  title: string;
  subtitle: string | null;
  updatedAt: string;
  icon: string | null;
  // A document or picture opens itself, in a tab of its own; the rest goes to its page.
  file?: VaultFile;
  to: string | { path: string; query: Record<string, unknown> };
}

const SEARCH_MESSAGES_FROM = 2;
const SEARCH_DELAY_MS = 300;
const MAX_ROWS = 50;
const IMAGE_EXTENSIONS = ['jpg', 'jpeg', 'png', 'heic', 'gif', 'webp'];
const FILE_ICONS: Record<string, string> = { pdf: 'pdf', doc: 'word', docx: 'word', txt: 'text' };

const props = defineProps<{ open: boolean }>();
const emit = defineEmits<{ close: [] }>();

const route = useRoute();
const chats = useAylaChats();
const lock = useAylaChatLock();
const projects = useAylaProjects();
const vault = useVault();
const preview = useFilePreview();

const dialogRef = useTemplateRef<HTMLDialogElement>('dialog');
const inputRef = useTemplateRef<HTMLInputElement>('input');
const titleId = useId();
const query = ref('');
const tab = ref<Tab>('all');
const messageIds = ref<string[]>([]);
const snippets = ref<Record<string, string>>({});
// Chat messages are searched in the database; until that answers, the list stays as it was instead of flashing empty.
const isSearchingMessages = ref(false);
let timer: ReturnType<typeof setTimeout> | undefined;

const TABS: { id: Tab; label: string }[] = [
  { id: 'all', label: AYLA_SEARCH_TAB_ALL },
  { id: 'chats', label: AYLA_SEARCH_TAB_CHATS },
  { id: 'items', label: AYLA_SEARCH_TAB_ITEMS },
  { id: 'documents', label: AYLA_SEARCH_TAB_DOCUMENTS },
  { id: 'images', label: AYLA_SEARCH_TAB_IMAGES },
  { id: 'projects', label: AYLA_SEARCH_TAB_PROJECTS },
];

// Accents and capitals do not matter ("cafe" finds "Café").
const fold = (text: string) => text.normalize('NFD').replace(/\p{M}/gu, '').toLocaleLowerCase('nl');
const needle = computed(() => fold(query.value.trim()));
const matches = (...texts: (string | null | undefined)[]) => !needle.value || texts.some((text) => fold(text ?? '').includes(needle.value));

const projectName = (conversation: Conversation) => {
  const projectId = projects.state.value.chatProjects[conversation.id];
  return projectId ? (projects.state.value.projects.find((project) => project.id === projectId)?.name ?? null) : null;
};

function chatLink(conversation: Conversation) {
  return isOnVault(route) && !lock.isLocked(conversation.id)
    ? { path: route.path, query: { ...route.query, chat: conversation.id } }
    : `/ayla/${conversation.id}`;
}

const itemLink = (id: string) => ({ path: '/kluis', query: { item: id } });
const extensionOf = (name: string) => getExtension(name);
const fileIcon = (name: string) => `/images/vault/files/${IMAGE_EXTENSIONS.includes(extensionOf(name)) ? 'image' : (FILE_ICONS[extensionOf(name)] ?? 'text')}.svg`;

const chatResults = computed<Result[]>(() =>
  chats.visibleConversations.value
    .filter((conversation) => matches(conversation.title, projectName(conversation)) || messageIds.value.includes(conversation.id))
    .map((conversation) => ({
      key: `chat-${conversation.id}`,
      kind: 'chat' as const,
      title: conversation.title,
      subtitle: snippets.value[conversation.id] ?? projectName(conversation),
      updatedAt: conversation.updatedAt,
      icon: null,
      to: chatLink(conversation),
    })),
);
const projectResults = computed(() => chatResults.value.filter((result) => result.key.startsWith('chat-') && projectChat(result)));
function projectChat(result: Result) {
  const conversation = chats.visibleConversations.value.find((candidate) => `chat-${candidate.id}` === result.key);
  return Boolean(conversation && projectName(conversation));
}
const itemResults = computed<Result[]>(() =>
  vault.state.value.items
    .filter((item) => matches(item.title, item.organisationName, item.description, ...item.skills))
    .map((item) => ({
      key: `item-${item.id}`,
      kind: 'item' as const,
      title: item.title,
      subtitle: item.organisationName,
      updatedAt: item.updatedAt,
      icon: item.files[0] ? fileIcon(item.files[0].name) : null,
      to: itemLink(item.id),
    })),
);
const fileResults = computed<Result[]>(() =>
  vault.state.value.items.flatMap((item) =>
    item.files
      .filter((file) => file.role === 'document' && matches(file.name))
      .map((file) => ({
        key: `file-${file.id}`,
        kind: 'file' as const,
        title: file.name,
        subtitle: item.title,
        updatedAt: item.updatedAt,
        icon: fileIcon(file.name),
        file,
        to: itemLink(item.id),
      })),
  ),
);
const isImage = (result: Result) => IMAGE_EXTENSIONS.includes(extensionOf(result.title));

const results = computed(() => {
  const byNewest = (list: Result[]) => [...list].sort((first, second) => second.updatedAt.localeCompare(first.updatedAt)).slice(0, MAX_ROWS);
  switch (tab.value) {
    case 'chats':
      return byNewest(chatResults.value);
    case 'items':
      return byNewest(itemResults.value);
    case 'documents':
      return byNewest(fileResults.value.filter((result) => !isImage(result)));
    case 'images':
      return byNewest(fileResults.value.filter(isImage));
    case 'projects':
      return byNewest(projectResults.value);
    default:
      return byNewest([...chatResults.value, ...itemResults.value, ...(needle.value ? fileResults.value : [])]);
  }
});

/** The text cut into pieces, the ones that are the typed words marked, to show them in bold. */
function pieces(text: string) {
  const word = query.value.trim().toLocaleLowerCase('nl');
  if (!word) return [{ text, isMatch: false }];
  const lower = text.toLocaleLowerCase('nl');
  const out: { text: string; isMatch: boolean }[] = [];
  let from = 0;
  for (let at = lower.indexOf(word); at !== -1; at = lower.indexOf(word, from)) {
    if (at > from) out.push({ text: text.slice(from, at), isMatch: false });
    out.push({ text: text.slice(at, at + word.length), isMatch: true });
    from = at + word.length;
  }
  if (from < text.length) out.push({ text: text.slice(from), isMatch: false });
  return out;
}

function dateLabel(value: string) {
  const date = readChatDate(value);
  if (!date) return '';
  const days = Math.round((new Date().setHours(0, 0, 0, 0) - new Date(date).setHours(0, 0, 0, 0)) / 86_400_000);
  if (days <= 0) return AYLA_TODAY;
  if (days === 1) return AYLA_YESTERDAY;
  return date.toLocaleDateString('nl-NL', { day: 'numeric', month: 'short', ...(date.getFullYear() === new Date().getFullYear() ? {} : { year: 'numeric' }) });
}

let searchCount = 0;
watch(query, () => {
  clearTimeout(timer);
  if (needle.value.length < SEARCH_MESSAGES_FROM) {
    searchCount++;
    isSearchingMessages.value = false;
    messageIds.value = [];
    snippets.value = {};
    return;
  }
  isSearchingMessages.value = true;
  timer = setTimeout(async () => {
    const mine = ++searchCount;
    const found = await chats.searchMessages(query.value);
    if (mine !== searchCount) return;
    messageIds.value = found.conversationIds;
    snippets.value = found.snippets;
    isSearchingMessages.value = false;
  }, SEARCH_DELAY_MS);
});

function show() {
  query.value = '';
  tab.value = 'all';
  messageIds.value = [];
  snippets.value = {};
  isSearchingMessages.value = false;
  // The vault is read once when it is not there yet (the search also works on the chat pages).
  if (vault.state.value.status !== 'ready') vault.load();
  if (!dialogRef.value?.open) dialogRef.value?.showModal();
  nextTick(() => inputRef.value?.focus());
}

function close() {
  dialogRef.value?.close();
}

// Opened and closed from outside with `open`.
watch(
  () => props.open,
  (isOpen) => (isOpen ? show() : dialogRef.value?.open && close()),
  { flush: 'post' },
);
onBeforeUnmount(() => clearTimeout(timer));

/** Arrow keys move through the results from the field and between them. */
function moveFocus(step: 1 | -1) {
  const items = Array.from(dialogRef.value?.querySelectorAll<HTMLElement>('[data-result]') ?? []);
  if (!items.length) return;
  const index = items.findIndex((item) => item === document.activeElement);
  const next = index === -1 ? (step === 1 ? 0 : items.length - 1) : index + step;
  if (next < 0) inputRef.value?.focus();
  else items[Math.min(next, items.length - 1)]?.focus();
}

/** A document or picture opens over the page itself (the file preview); the search closes first. */
function openFile(file: VaultFile) {
  close();
  preview.open(file);
}

function backdropClick(event: MouseEvent) {
  if (event.target === dialogRef.value) close();
}
</script>

<template>
  <dialog
    ref="dialog"
    :aria-labelledby="titleId"
    class="m-auto mt-[12vh] hidden h-[min(36rem,76vh)] w-full max-w-2xl flex-col open:flex overflow-hidden rounded-2xl border border-card-line bg-white p-0 shadow-modal backdrop:bg-ink/40 max-sm:mt-0 max-sm:h-full max-sm:max-h-none max-sm:max-w-none max-sm:rounded-none"
    @close="emit('close')"
    @click="backdropClick"
    @keydown.down.prevent="moveFocus(1)"
    @keydown.up.prevent="moveFocus(-1)"
  >
    <h2 :id="titleId" class="sr-only">{{ AYLA_SEARCH_PLACEHOLDER }}</h2>

    <div class="flex items-center gap-3 px-5 pb-2 pt-4">
      <LayoutPaveIcon name="search" class="size-5 shrink-0 text-brand" aria-hidden="true" />
      <input
        ref="input"
        v-model="query"
        type="search"
        autocomplete="off"
        :aria-label="AYLA_SEARCH_PLACEHOLDER"
        :placeholder="AYLA_SEARCH_PLACEHOLDER"
        class="h-10 min-w-0 flex-1 appearance-none bg-transparent text-lg font-medium text-heading placeholder:text-subtle/50 focus:outline-none [&::-webkit-search-cancel-button]:hidden [&::-webkit-search-cancel-button]:appearance-none"
        @keydown.enter="($event.target as HTMLElement).blur(); moveFocus(1)"
      />
      <button
        v-if="query"
        type="button"
        class="rounded-lg px-2 py-1 text-sm font-medium text-subtle hover:bg-surface hover:text-heading focus-visible:outline-2 focus-visible:outline-brand"
        @click="query = ''; inputRef?.focus()"
      >
        {{ AYLA_SEARCH_CLEAR }}
      </button>
      <span v-if="query" class="h-5 w-px bg-card-line" aria-hidden="true" />
      <button
        type="button"
        class="flex size-8 items-center justify-center rounded-lg text-subtle hover:bg-surface hover:text-heading focus-visible:outline-2 focus-visible:outline-brand"
        @click="close"
      >
        <svg viewBox="0 0 12 12" class="size-3.5" fill="none" stroke="currentColor" stroke-width="1.6" stroke-linecap="round" aria-hidden="true">
          <path d="M2 2l8 8M10 2L2 10" />
        </svg>
        <span class="sr-only">{{ AYLA_SEARCH_CLOSE }}</span>
      </button>
    </div>

    <div class="flex gap-1 overflow-x-auto px-4 pb-3 [scrollbar-width:none]" role="tablist" :aria-label="AYLA_SEARCH_CHATS">
      <button
        v-for="item in TABS"
        :key="item.id"
        type="button"
        role="tab"
        :aria-selected="tab === item.id"
        :class="tab === item.id ? 'bg-tint text-heading' : 'text-subtle hover:bg-surface hover:text-heading'"
        class="h-9 shrink-0 rounded-full px-4 text-sm font-medium focus-visible:outline-2 focus-visible:outline-brand"
        @click="tab = item.id"
      >
        {{ item.label }}
      </button>
    </div>

    <ul v-if="results.length" class="min-h-0 flex-1 overflow-y-auto px-2 pb-3">
      <li v-for="result in results" :key="result.key">
        <button v-if="result.file" type="button" data-result class="flex w-full items-center gap-4 rounded-xl px-3 py-3 text-left hover:bg-surface focus-visible:bg-surface focus-visible:outline-2 focus-visible:outline-brand" @click="openFile(result.file)">
          <img v-if="result.icon" :src="result.icon" alt="" class="size-5 shrink-0" />
          <LayoutPaveIcon v-else :name="result.kind === 'chat' ? 'chat' : 'folder'" class="size-5 shrink-0 text-subtle" aria-hidden="true" />
          <span class="flex min-w-0 flex-1 flex-col">
            <span class="truncate text-base font-medium text-heading">
              <template v-for="(piece, index) in pieces(result.title)" :key="index">
                <strong v-if="piece.isMatch" class="font-bold">{{ piece.text }}</strong>
                <template v-else>{{ piece.text }}</template>
              </template>
            </span>
            <span v-if="result.subtitle" class="truncate text-sm text-subtle">
              <template v-for="(piece, index) in pieces(result.subtitle)" :key="index">
                <strong v-if="piece.isMatch" class="font-bold text-heading">{{ piece.text }}</strong>
                <template v-else>{{ piece.text }}</template>
              </template>
            </span>
          </span>
          <span class="shrink-0 text-sm text-subtle">{{ dateLabel(result.updatedAt) }}</span>
        </button>
        <NuxtLink
          v-else
          :to="result.to"
          data-result
          class="flex items-center gap-4 rounded-xl px-3 py-3 hover:bg-surface focus-visible:bg-surface focus-visible:outline-2 focus-visible:outline-brand"
          @click="close"
        >
          <img v-if="result.icon" :src="result.icon" alt="" class="size-5 shrink-0" />
          <LayoutPaveIcon v-else :name="result.kind === 'chat' ? 'chat' : 'folder'" class="size-5 shrink-0 text-subtle" aria-hidden="true" />
          <span class="flex min-w-0 flex-1 flex-col">
            <span class="truncate text-base font-medium text-heading">
              <template v-for="(piece, index) in pieces(result.title)" :key="index">
                <strong v-if="piece.isMatch" class="font-bold">{{ piece.text }}</strong>
                <template v-else>{{ piece.text }}</template>
              </template>
            </span>
            <span v-if="result.subtitle" class="truncate text-sm text-subtle">
              <template v-for="(piece, index) in pieces(result.subtitle)" :key="index">
                <strong v-if="piece.isMatch" class="font-bold text-heading">{{ piece.text }}</strong>
                <template v-else>{{ piece.text }}</template>
              </template>
            </span>
          </span>
          <span class="shrink-0 text-sm text-subtle">{{ dateLabel(result.updatedAt) }}</span>
        </NuxtLink>
      </li>
    </ul>
    <p v-else-if="!isSearchingMessages" role="status" class="px-6 pb-10 pt-6 text-center text-sm text-subtle">
      {{ needle ? getNoChatsFoundMessage(query.trim()) : AYLA_SEARCH_EMPTY }}
    </p>
  </dialog>
</template>
