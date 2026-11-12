<script setup lang="ts">
import type { RealtimeChannel } from '@supabase/supabase-js';
import type { Conversation } from '~/types/ayla';

const SEARCH_MESSAGES_FROM = 2;
const SEARCH_DELAY_MS = 300;

const route = useRoute();
const chats = useAylaChats();
const conversation = useAylaConversation();
const { isDrawerOpen, isCollapsed, setCollapsed, closeDrawer } = useAylaPanel();

const isSearching = ref(false);
const search = ref('');
const messageMatchIds = ref<string[]>([]);
const actionError = ref<string | null>(null);
const searchInputRef = useTemplateRef<HTMLInputElement>('searchInput');
const asideRef = useTemplateRef<HTMLElement>('aside');
const FOCUSABLE = 'a[href], button:not([disabled]), input:not([disabled]), [tabindex]:not([tabindex="-1"])';
let channel: RealtimeChannel | null = null;
let searchTimer: ReturnType<typeof setTimeout> | undefined;

const undoDelete = useUndoDelay({
  onCommit: commitDelete,
  onUndo: (id) => chats.unhide(id),
});

const activeId = computed(() => (typeof route.params.id === 'string' ? route.params.id : null));
const trimmedSearch = computed(() => search.value.trim().toLocaleLowerCase('nl'));
const shownConversations = computed(() => {
  if (!trimmedSearch.value) return chats.visibleConversations.value;
  return chats.visibleConversations.value.filter(
    (conversation) =>
      conversation.title.toLocaleLowerCase('nl').includes(trimmedSearch.value) ||
      messageMatchIds.value.includes(conversation.id),
  );
});
const sections = computed(() => splitPinned(shownConversations.value));
const transcript = computed(() => {
  const state = conversation.state.value;
  const isOpenChat = Boolean(activeId.value) && state.conversationId === activeId.value;
  return isOpenChat ? state.messages : [];
});
const status = computed(() => chats.state.value.status);
const hasNoChats = computed(() => status.value === 'ready' && chats.visibleConversations.value.length === 0);
const hasNoResults = computed(() => Boolean(trimmedSearch.value) && shownConversations.value.length === 0);

async function commitDelete(id: string) {
  const { isFailed } = await chats.deleteHidden(id);
  if (isFailed) actionError.value = AYLA_DELETE_FAILED;
  else if (activeId.value === id) await navigateTo('/');
}

function removeChat(item: Conversation) {
  actionError.value = null;
  chats.hide(item.id);
  undoDelete.schedule(item.id);
}

async function togglePin(item: Conversation) {
  actionError.value = null;
  const { isFailed } = await chats.setPinned(item.id, !item.pinnedAt);
  if (isFailed) actionError.value = AYLA_PIN_FAILED;
}

async function renameChat(item: Conversation, title: string) {
  actionError.value = null;
  const { isFailed } = await chats.rename(item.id, title);
  if (isFailed) actionError.value = AYLA_RENAME_FAILED;
}

async function toggleSearch() {
  isSearching.value = !isSearching.value;
  search.value = '';
  if (!isSearching.value) return;
  await nextTick();
  searchInputRef.value?.focus();
}

const asideClass = computed(() => {
  if (isDrawerOpen.value) return 'visible translate-x-0 shadow-xl';
  if (isCollapsed.value) return 'invisible -translate-x-full';
  return 'invisible -translate-x-full md:visible md:static md:translate-x-0';
});

function getFocusable() {
  return Array.from(asideRef.value?.querySelectorAll<HTMLElement>(FOCUSABLE) ?? []);
}

// Keeps Tab inside the drawer while it is open.
function trapFocus(event: KeyboardEvent) {
  if (!isDrawerOpen.value || event.key !== 'Tab') return;
  const focusable = getFocusable();
  const first = focusable[0];
  const last = focusable.at(-1);
  if (event.shiftKey && document.activeElement === first) {
    event.preventDefault();
    last?.focus();
  } else if (!event.shiftKey && document.activeElement === last) {
    event.preventDefault();
    first?.focus();
  }
}

function closeDrawerAndReturnFocus() {
  if (!isDrawerOpen.value) return;
  closeDrawer();
  // Back to the logo that opened it: the menu logo on small screens, Ayla's logo on wider ones.
  const openers = Array.from(document.querySelectorAll<HTMLElement>('[data-panel-opener], [data-menu-opener]'));
  openers.find((opener) => opener.offsetParent !== null)?.focus();
}

watch(isDrawerOpen, async (isOpen) => {
  if (!isOpen) return;
  await nextTick();
  getFocusable()[0]?.focus();
});

async function searchInMessages() {
  if (trimmedSearch.value.length < SEARCH_MESSAGES_FROM) {
    messageMatchIds.value = [];
    return;
  }
  const { conversationIds } = await chats.searchMessages(search.value);
  messageMatchIds.value = conversationIds;
}

watch(search, () => {
  clearTimeout(searchTimer);
  searchTimer = setTimeout(searchInMessages, SEARCH_DELAY_MS);
});

onMounted(async () => {
  await chats.load();
  channel = await chats.subscribe();
});

onBeforeUnmount(() => {
  clearTimeout(searchTimer);
  chats.unsubscribe(channel);
});
</script>

<template>
  <div class="contents">
    <div v-if="isDrawerOpen" class="fixed inset-0 z-30 bg-ink/40" aria-hidden="true" @click="closeDrawer" />
    <aside
      ref="aside"
      aria-label="Chatgeschiedenis"
      :role="isDrawerOpen ? 'dialog' : undefined"
      :aria-modal="isDrawerOpen ? 'true' : undefined"
      :class="[asideClass, { 'md:hidden': isCollapsed && !isDrawerOpen }]"
      class="fixed inset-y-0 left-0 z-40 flex w-66.5 flex-col border-r border-rail-line bg-white transition-transform motion-reduce:transition-none"
      @keydown.esc="closeDrawerAndReturnFocus"
      @keydown="trapFocus"
    >
      <div
        :class="transcript.length ? 'h-76.75 shrink-0 border-b border-rail-line' : 'min-h-0 flex-1'"
        class="flex flex-col"
      >
        <div class="flex items-center pl-5.5 pr-5.25 pt-4.75">
          <NuxtLink
            to="/"
            class="flex flex-1 items-center gap-2 rounded-md text-sm font-medium text-heading focus-visible:outline-2 focus-visible:outline-brand"
            @click="closeDrawer"
          >
            <LayoutPaveIcon name="compose" class="size-4.75" />
            {{ AYLA_NEW_CHAT }}
          </NuxtLink>
          <button
            type="button"
            :aria-pressed="isSearching"
            class="flex size-6 items-center justify-center rounded-md focus-visible:outline-2 focus-visible:outline-brand"
            @click="toggleSearch"
          >
            <LayoutPaveIcon name="search" class="size-5 text-heading" />
            <span class="sr-only">{{ AYLA_SEARCH_CHATS }}</span>
          </button>
          <button
            type="button"
            class="ml-1.75 flex size-6 items-center justify-center rounded-md focus-visible:outline-2 focus-visible:outline-brand"
            @click="isDrawerOpen ? closeDrawerAndReturnFocus() : setCollapsed(true)"
          >
            <AylaPanelIcon />
            <span class="sr-only">{{ AYLA_CLOSE_PANEL }}</span>
          </button>
        </div>

        <div v-if="isSearching" class="px-5.5 pt-3">
          <label for="ayla-chat-search" class="sr-only">{{ AYLA_SEARCH_CHATS }}</label>
          <input
            id="ayla-chat-search"
            ref="searchInput"
            v-model="search"
            type="search"
            :placeholder="AYLA_SEARCH_CHATS"
            class="w-full rounded-lg border border-rail-line bg-white px-3 py-2 text-sm text-heading placeholder:text-subtle focus-visible:outline-2 focus-visible:outline-brand"
          />
        </div>

        <div class="min-h-0 flex-1 space-y-5.25 overflow-y-auto px-5.5 pb-4 pt-9.5">
          <p v-if="actionError" role="alert" class="text-sm text-danger">{{ actionError }}</p>
          <p v-if="status === 'loading' || status === 'idle'" class="text-sm text-subtle">{{ AYLA_CHATS_LOADING }}</p>
          <AylaNotice
            v-else-if="status === 'failed'"
            :message="AYLA_CHATS_UNAVAILABLE"
            :action-label="AYLA_RETRY"
            @action="chats.load"
          />
          <div v-else-if="hasNoChats" class="text-sm">
            <p class="font-medium text-heading">{{ AYLA_NO_CHATS }}</p>
            <p class="mt-1 text-subtle">{{ AYLA_NO_CHATS_BODY }}</p>
          </div>
          <p v-else-if="hasNoResults" class="text-sm text-subtle">{{ getNoChatsFoundMessage(search) }}</p>

          <AylaChatSection
            v-if="sections.pinned.length"
            :title="AYLA_PINNED_HEADING"
            :conversations="sections.pinned"
            :active-id="activeId"
            :can-pin="chats.state.value.canPin"
            @open="closeDrawer"
            @toggle-pin="togglePin"
            @rename="renameChat"
            @remove="removeChat"
          />
          <AylaChatSection
            v-if="sections.others.length"
            :title="AYLA_CHATS_HEADING"
            :conversations="sections.others"
            :active-id="activeId"
            :can-pin="chats.state.value.canPin"
            is-foldable
            @open="closeDrawer"
            @toggle-pin="togglePin"
            @rename="renameChat"
            @remove="removeChat"
          />
        </div>
      </div>

      <AylaTranscript
        v-if="transcript.length"
        :messages="transcript"
        :is-writing="conversation.state.value.isWriting"
        @edit-question="conversation.changeLastTurn('editQuestion')"
      />
    </aside>

    <AylaUndoToast v-if="undoDelete.pendingId.value" :message="AYLA_CHAT_DELETED" @undo="undoDelete.undo" />
  </div>
</template>
