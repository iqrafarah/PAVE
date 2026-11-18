<script setup lang="ts">
import type { RealtimeChannel } from '@supabase/supabase-js';
import type { Conversation } from '~/types/ayla';

const CLOCK_INTERVAL_MS = 60_000;

const route = useRoute();
const chats = useAylaChats();
const conversation = useAylaConversation();
const lock = useAylaChatLock();

// The panel is as wide as the user pulls it (the handle on its right edge or the arrow keys), kept in this browser.
const DEFAULT_WIDTH = 266;
const MIN_WIDTH = 220;
const MAX_WIDTH = 480;
const KEY_STEP = 16;
const WIDTH_KEY = 'pave-chat-panel-width';
const width = ref(DEFAULT_WIDTH);
let dragStart: { x: number; width: number } | null = null;

function clampWidth(value: number) {
  return Math.min(MAX_WIDTH, Math.max(MIN_WIDTH, Math.round(value)));
}

function saveWidth() {
  try {
    localStorage.setItem(WIDTH_KEY, String(width.value));
  } catch {
    // Not remembered, still resizes.
  }
}

function startResize(event: PointerEvent) {
  dragStart = { x: event.clientX, width: width.value };
  (event.currentTarget as HTMLElement).setPointerCapture(event.pointerId);
}

function resize(event: PointerEvent) {
  if (dragStart) width.value = clampWidth(dragStart.width + event.clientX - dragStart.x);
}

function stopResize() {
  if (!dragStart) return;
  dragStart = null;
  saveWidth();
}

function resizeWithKeys(event: KeyboardEvent) {
  const change = { ArrowLeft: -KEY_STEP, ArrowRight: KEY_STEP }[event.key];
  if (change === undefined && event.key !== 'Home') return;
  event.preventDefault();
  width.value = change === undefined ? DEFAULT_WIDTH : clampWidth(width.value + change);
  saveWidth();
}

function startFreshChat() {
  projects.state.value.newChatProjectId = null;
  closeDrawer();
  // On the vault the link may point at the page you are on already: the chat starts fresh here.
  if (isOnVault(route)) {
    conversation.startNew();
    conversation.focusComposer();
  }
}
const projects = useAylaProjects();
const { isDrawerOpen, isCollapsed, setCollapsed, closeDrawer } = useAylaPanel();

const isSearching = ref(false);
const actionError = ref<string | null>(null);
// Locking a chat: the question first, then the PIN when the account has none yet.
const lockTarget = ref<Conversation | null>(null);
const isMakingPin = ref(false);
const pinError = ref<string | null>(null);
const lockConfirmRef = useTemplateRef<{ open: () => void }>('lockConfirm');
const asideRef = useTemplateRef<HTMLElement>('aside');
const FOCUSABLE = 'a[href], button:not([disabled]), input:not([disabled]), [tabindex]:not([tabindex="-1"])';
let channel: RealtimeChannel | null = null;
let clockTimer: ReturnType<typeof setInterval> | undefined;
// The groups and times move along with the clock, so a chat from before midnight moves to "Gisteren".
const now = ref(new Date());
const openMenu = useAylaOpenMenu();

// Like ChatGPT: first the question, then the chat simply leaves the list. No message and no undo.
const deleteTarget = ref<Conversation | null>(null);
const deleteConfirmRef = useTemplateRef<{ open: () => void }>('deleteConfirm');

// On the vault the open chat is the one in the page, not one in the address.
const activeId = computed(() =>
  typeof route.params.id === 'string' ? route.params.id : isOnVault(route) ? conversation.state.value.conversationId : null,
);
const shownConversations = computed(() => chats.visibleConversations.value);
const sections = computed(() => groupConversations(shownConversations.value, now.value));
// Vastgezet first, then Projecten, then one "Recent" group (all the other chats, newest first), like ChatGPT.
const pinnedSections = computed(() => sections.value.filter((section) => section.kind === 'pinned'));
const recentSections = computed(() => {
  // Chats in a project show under the project; searching still finds them.
  const conversations = sections.value
    .filter((section) => section.kind !== 'pinned')
    .flatMap((section) => section.conversations)
    .filter((conversation) => !projects.state.value.chatProjects[conversation.id]);
  return conversations.length ? [{ kind: 'recent', title: AYLA_RECENT, conversations }] : [];
});
const transcript = computed(() => {
  const state = conversation.state.value;
  const isOpenChat = Boolean(activeId.value) && state.conversationId === activeId.value;
  return isOpenChat ? state.messages : [];
});
const status = computed(() => chats.state.value.status);
const hasNoChats = computed(() => status.value === 'ready' && chats.visibleConversations.value.length === 0);

function removeChat(item: Conversation) {
  actionError.value = null;
  deleteTarget.value = item;
  deleteConfirmRef.value?.open();
}

async function confirmDelete() {
  const item = deleteTarget.value;
  deleteTarget.value = null;
  if (!item) return;
  chats.hide(item.id);
  if (activeId.value === item.id) await navigateTo(newChatPath(route));
  const { isFailed } = await chats.deleteHidden(item.id);
  if (isFailed) actionError.value = AYLA_DELETE_FAILED;
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

function askToLock(item: Conversation) {
  actionError.value = null;
  lockTarget.value = item;
  lockConfirmRef.value?.open();
}

async function confirmLock() {
  if (lock.state.value.hasPin) await lockSelected();
  else {
    pinError.value = null;
    isMakingPin.value = true;
  }
}

async function makePin(pin: string) {
  const { isFailed } = await lock.createPin(pin);
  if (isFailed) {
    pinError.value = AYLA_PINCODE_FAILED;
    return;
  }
  isMakingPin.value = false;
  await lockSelected();
}

async function lockSelected() {
  const item = lockTarget.value;
  if (!item) return;
  const { isFailed } = await lock.lockChat(item.id);
  lockTarget.value = null;
  if (isFailed) actionError.value = AYLA_LOCK_FAILED;
  else if (activeId.value === item.id) await navigateTo(newChatPath(route));
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

onMounted(async () => {
  clockTimer = setInterval(() => {
    if (openMenu.openCount.value === 0) now.value = new Date();
  }, CLOCK_INTERVAL_MS);
  try {
    width.value = clampWidth(Number(localStorage.getItem(WIDTH_KEY)) || DEFAULT_WIDTH);
  } catch {
    width.value = DEFAULT_WIDTH;
  }
  await Promise.all([chats.load(), lock.load()]);
  channel = await chats.subscribe();
});

onBeforeUnmount(() => {
  clearInterval(clockTimer);
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
      :style="{ '--ayla-sidebar-w': `${width}px` }"
      class="quiet-scroll fixed inset-y-0 left-0 z-40 flex w-66.5 flex-col border-r md:w-(--ayla-sidebar-w) border-rail-line bg-white transition-transform motion-reduce:transition-none"
      @keydown.esc="closeDrawerAndReturnFocus"
      @keydown="trapFocus"
    >
      <div
        :class="transcript.length ? 'h-76.75 shrink-0 border-b border-rail-line' : 'min-h-0 flex-1'"
        class="flex flex-col"
      >
        <div class="flex items-center pl-5.5 pr-5.25 pt-4.75">
          <NuxtLink
            :to="newChatPath(route)"
            class="flex flex-1 items-center gap-2 rounded-md text-sm font-medium text-heading focus-visible:outline-2 focus-visible:outline-brand"
            @click="startFreshChat"
          >
            <LayoutPaveIcon name="compose" class="size-4 text-brand" />
            {{ AYLA_NEW_CHAT }}
          </NuxtLink>
          <button
            type="button"
            aria-haspopup="dialog"
            class="flex size-6 items-center justify-center rounded-md focus-visible:outline-2 focus-visible:outline-brand"
            @click="isSearching = true"
          >
            <LayoutPaveIcon name="search" class="size-4 text-brand" />
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

          <AylaChatSection
            v-for="section in pinnedSections"
            :key="section.kind"
            :title="section.title"
            :conversations="section.conversations"
            :active-id="activeId"
            :can-pin="chats.state.value.canPin"
            :now="now"
            collapse-key="pinned"
            @open="closeDrawer"
            @toggle-pin="togglePin"
            @rename="renameChat"
            @remove="removeChat"
            @lock="askToLock"
          />

          <AylaProjectList
            :conversations="chats.visibleConversations.value"
            :can-pin="chats.state.value.canPin"
            :now="now"
            @open="closeDrawer"
            @toggle-pin="togglePin"
            @rename="renameChat"
            @remove="removeChat"
            @lock="askToLock"
          />

          <AylaChatSection
            v-for="section in recentSections"
            :key="section.kind"
            :title="section.title"
            :conversations="section.conversations"
            :active-id="activeId"
            :can-pin="chats.state.value.canPin"
            :now="now"
            collapse-key="recent"
            @open="closeDrawer"
            @toggle-pin="togglePin"
            @rename="renameChat"
            @remove="removeChat"
            @lock="askToLock"
          />
        </div>
      </div>

      <AylaTranscript
        v-if="transcript.length"
        :messages="transcript"
        :is-writing="conversation.state.value.isWriting"
        @edit-question="conversation.changeLastTurn('editQuestion')"
      />
      <div
        role="separator"
        aria-orientation="vertical"
        tabindex="0"
        :aria-label="AYLA_PANEL_RESIZE"
        :aria-valuenow="width"
        :aria-valuemin="MIN_WIDTH"
        :aria-valuemax="MAX_WIDTH"
        class="absolute inset-y-0 -right-1 z-10 hidden w-2 cursor-col-resize touch-none hover:bg-brand/20 focus-visible:bg-brand/30 focus-visible:outline-none md:block"
        @pointerdown="startResize"
        @pointermove="resize"
        @pointerup="stopResize"
        @pointercancel="stopResize"
        @dblclick="((width = DEFAULT_WIDTH), saveWidth())"
        @keydown="resizeWithKeys"
      />
    </aside>

    <AylaSearchDialog :open="isSearching" @close="isSearching = false" />

    <LayoutConfirmSheet
      ref="lockConfirm"
      :title="AYLA_LOCK_QUESTION"
      :message="AYLA_LOCK_BODY"
      :confirm-label="AYLA_LOCK_CONFIRM"
      is-calm
      @confirm="confirmLock"
    />
    <AylaPinDialog v-if="isMakingPin" mode="create" :error="pinError" @complete="makePin" @close="isMakingPin = false" />

    <LayoutConfirmSheet
      ref="deleteConfirm"
      :title="AYLA_DELETE_QUESTION"
      :message="deleteTarget ? getDeleteChatMessage(deleteTarget.title) : undefined"
      :confirm-label="AYLA_DELETE_CONFIRM"
      @confirm="confirmDelete"
    />
  </div>
</template>
