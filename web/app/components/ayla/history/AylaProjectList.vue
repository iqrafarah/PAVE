<script setup lang="ts">
import type { Conversation, Project, RowMenuItem } from '~/types/ayla';

// "Projecten" in the chat history, drawn like the chat groups under it: a small grey heading, rows with the name.
// The + opens the sheet for a new project. Without the database table the + still shows, and says why it cannot save.
const DROP_MESSAGE_MS = 3000;

const props = defineProps<{
  // The chats of the history; the ones in a project show under it.
  conversations: Conversation[];
  canPin: boolean;
  now: Date;
}>();

const emit = defineEmits<{
  open: [];
  togglePin: [conversation: Conversation];
  rename: [conversation: Conversation, title: string];
  remove: [conversation: Conversation];
  lock: [conversation: Conversation];
}>();

const route = useRoute();
const projects = useAylaProjects();
const chats = useAylaChats();

const isCreating = ref(false);
const error = ref<string | null>(null);
const headingId = useId();
const listId = useId();
const isCollapsed = useCollapsed('projects');
const lock = useAylaChatLock();

// A chat dragged from the list below onto a project goes into that project.
const dropTargetId = ref<string | null>(null);
const dropMessage = ref<{ text: string; isError: boolean } | null>(null);
let dropTimer: ReturnType<typeof setTimeout> | undefined;

// Settings, pin and delete in the ⋯ menu of a project, like the menu of a chat.
const editing = ref<Project | null>(null);
const deleting = ref<Project | null>(null);
const editError = ref<string | null>(null);
const rowError = ref<string | null>(null);
const deleteRef = useTemplateRef<{ open: () => void }>('deleteConfirm');

function menuItemsFor(project: Project): RowMenuItem[] {
  const items: RowMenuItem[] = [{ id: 'settings', label: AYLA_PROJECT_SETTINGS }];
  if (projects.state.value.canPin) items.push({ id: 'pin', label: project.pinnedAt ? AYLA_PROJECT_UNPIN : AYLA_PROJECT_PIN });
  items.push({ id: 'delete', label: AYLA_DELETE, isDanger: true });
  return items;
}

async function handleMenuChoice(project: Project, id: string) {
  rowError.value = null;
  if (id === 'settings') {
    editError.value = null;
    editing.value = project;
  }
  if (id === 'pin') {
    const { isFailed } = await projects.setPinned(project.id, !project.pinnedAt);
    if (isFailed) rowError.value = AYLA_PIN_FAILED;
  }
  if (id === 'delete') {
    deleting.value = project;
    deleteRef.value?.open();
  }
}

async function startChat(projectId: string) {
  emit('open');
  await projects.startChatIn(projectId);
}

async function saveSettings(name: string, instructions: string) {
  if (!editing.value) return;
  editError.value = null;
  const { isFailed } = await projects.update(editing.value.id, { name, instructions });
  if (isFailed) editError.value = AYLA_PROJECT_FAILED;
  else editing.value = null;
}

async function confirmDelete() {
  const project = deleting.value;
  deleting.value = null;
  if (!project) return;
  const { isFailed } = await projects.remove(project.id);
  if (isFailed) rowError.value = AYLA_PROJECT_FAILED;

}

const status = computed(() => projects.state.value.status);
const isShown = computed(() => status.value === 'ready' || status.value === 'unavailable');
const activeChatId = computed(() =>
  route.path.startsWith('/ayla/') ? String(route.params.id) : typeof route.query.chat === 'string' ? route.query.chat : null,
);
const hasLockedChats = computed(() => lock.state.value.lockedIds.length > 0);
const isUnlocked = computed(() => lock.state.value.isUnlocked);
// Like a project: "Nu vergrendelen" and a new locked chat, both only while the chats are unlocked.
const lockedMenuItems = computed<RowMenuItem[]>(() =>
  isUnlocked.value
    ? [
        { id: 'relock', label: AYLA_LOCKED_RELOCK },
        { id: 'new', label: AYLA_LOCKED_NEW_CHAT },
      ]
    : [],
);

// Vergrendelde chats opens and closes under its row like a project, but only after the PIN of this tab.
const isLockedOpen = useState('ayla-locked-open', () => false);
const isAskingPin = ref(false);
const isCheckingPin = ref(false);
const pinError = ref<string | null>(null);
const resetRef = useTemplateRef<{ open: () => void }>('resetConfirm');

const lockedChats = computed(() =>
  chats.state.value.conversations
    .filter((conversation) => lock.isLocked(conversation.id) && !chats.state.value.hiddenIds.includes(conversation.id))
    .sort((first, second) => second.updatedAt.localeCompare(first.updatedAt)),
);

function toggleLocked() {
  if (isUnlocked.value) {
    isLockedOpen.value = !isLockedOpen.value;
    return;
  }
  pinError.value = null;
  if (lock.state.value.hasPin) isAskingPin.value = true;
}

async function checkPin(pin: string) {
  isCheckingPin.value = true;
  pinError.value = null;
  const result = await lock.checkPin(pin);
  isCheckingPin.value = false;
  if (result === 'right') {
    isAskingPin.value = false;
    isLockedOpen.value = true;
  } else {
    pinError.value = { wrong: AYLA_PIN_WRONG, blocked: AYLA_PIN_BLOCKED, failed: AYLA_PINCODE_FAILED }[result];
  }
}

async function resetPin() {
  isAskingPin.value = false;
  const { isFailed } = await lock.resetPin();
  if (isFailed) rowError.value = AYLA_PINCODE_FAILED;
  else await navigateTo('/');
}

// Locking again closes the list; an open locked chat keeps it open, so you see where you are.
watch(isUnlocked, (unlocked) => {
  if (!unlocked) isLockedOpen.value = false;
});
watch(
  activeChatId,
  (chatId) => {
    if (chatId && lock.isLocked(chatId) && isUnlocked.value) isLockedOpen.value = true;
  },
  { immediate: true },
);

async function handleLockedChoice(id: string) {
  emit('open');
  if (id === 'relock') await lock.relock();
  if (id === 'new') await lock.startLockedChat();
}

// A project opens and closes under its row, like the folders in ChatGPT; its chats open without leaving the list.
const openIds = useState<string[]>('ayla-open-projects', () => []);

function isOpen(projectId: string) {
  return openIds.value.includes(projectId);
}

function toggleOpen(projectId: string) {
  openIds.value = isOpen(projectId) ? openIds.value.filter((id) => id !== projectId) : [...openIds.value, projectId];
}

function chatsOf(projectId: string) {
  // A pinned chat moves up to Vastgezet and comes back here when it is unpinned.
  return props.conversations
    .filter((conversation) => projects.state.value.chatProjects[conversation.id] === projectId && !conversation.pinnedAt)
    .sort((first, second) => second.updatedAt.localeCompare(first.updatedAt));
}

// The chat that is open keeps its project open, so you see where you are.
watch(
  [activeChatId, () => projects.state.value.chatProjects],
  ([chatId]) => {
    const projectId = chatId ? projects.state.value.chatProjects[chatId] : null;
    if (projectId && !isOpen(projectId)) openIds.value = [...openIds.value, projectId];
  },
  { immediate: true },
);

function startCreating() {
  error.value = null;
  isCreating.value = true;
}

async function create(name: string, instructions: string) {
  error.value = null;
  if (status.value === 'unavailable') await projects.load();
  if (status.value === 'unavailable') {
    error.value = AYLA_PROJECTS_NOT_READY;
    return;
  }
  const { project, isFailed } = await projects.create(name);
  if (isFailed || !project) {
    error.value = AYLA_PROJECT_FAILED;
    return;
  }
  if (instructions) await projects.update(project.id, { instructions });
  isCreating.value = false;
  openIds.value = [...openIds.value, project.id];
}

function isChatDrag(event: DragEvent) {
  return Boolean(event.dataTransfer?.types.includes(CHAT_DRAG_TYPE));
}

function dragOver(event: DragEvent, id: string) {
  if (!isChatDrag(event)) return;
  event.preventDefault();
  if (event.dataTransfer) event.dataTransfer.dropEffect = 'move';
  dropTargetId.value = id;
}

async function drop(event: DragEvent, project: { id: string; name: string }) {
  dropTargetId.value = null;
  const chatId = event.dataTransfer?.getData(CHAT_DRAG_TYPE);
  if (!chatId) return;
  event.preventDefault();
  const { isFailed } = await projects.moveChat(chatId, project.id);
  // A chat that moved just shows up under its project; only a failure is said out loud.
  dropMessage.value = isFailed ? { text: AYLA_PROJECT_MOVE_FAILED, isError: true } : null;
  clearTimeout(dropTimer);
  dropTimer = setTimeout(() => (dropMessage.value = null), DROP_MESSAGE_MS);
}

onMounted(async () => {
  await projects.load();
  await projects.loadMembership();
});
onBeforeUnmount(() => clearTimeout(dropTimer));
</script>

<template>
  <section v-if="isShown" :aria-labelledby="headingId">
    <div class="group/heading flex h-6 items-center justify-between">
      <h2 :id="headingId" class="text-xs font-medium text-subtle">
        <button
          type="button"
          :aria-expanded="!isCollapsed"
          :aria-controls="listId"
          class="-mx-1 flex items-center gap-1 rounded-md px-1 hover:text-heading focus-visible:outline-2 focus-visible:outline-brand"
          @click="isCollapsed = !isCollapsed"
        >
          {{ AYLA_PROJECTS }}
          <LayoutPaveIcon name="chevronRight" :class="isCollapsed ? '' : 'rotate-90'" class="size-2 transition-transform" />
        </button>
      </h2>
      <button
        type="button"
        class="-mr-1 flex size-6 items-center justify-center rounded-md text-brand hover:bg-surface focus-visible:outline-2 focus-visible:outline-brand md:opacity-0 md:group-focus-within/heading:opacity-100 md:group-hover/heading:opacity-100"
        :title="AYLA_NEW_PROJECT"
        @click="startCreating"
      >
        <LayoutIcon name="plus" class="size-4" />
        <span class="sr-only">{{ AYLA_NEW_PROJECT }}</span>
      </button>
    </div>

    <ul v-show="!isCollapsed" :id="listId" class="mt-2 space-y-0.5">
      <li v-for="project in projects.state.value.projects" :key="project.id">
        <div
          class="group relative -mx-2 flex items-center rounded-md hover:bg-surface"
          :class="dropTargetId === project.id ? 'bg-tint outline-2 outline-brand' : ''"
          @dragover="dragOver($event, project.id)"
          @dragleave="dropTargetId = null"
          @drop="drop($event, project)"
        >
          <button
            type="button"
            :aria-expanded="isOpen(project.id)"
            class="flex min-w-0 flex-1 items-center gap-2 rounded-md px-2 py-1 text-left max-md:pr-18 focus-visible:outline-2 focus-visible:outline-brand"
            @click="toggleOpen(project.id)"
          >
            <VaultIcon src="/images/vault/icons/FolderOutline.svg" class="size-4 shrink-0 text-brand" />
            <span class="min-w-0 flex-1 truncate text-sm font-medium text-heading">{{ project.name }}</span>
          </button>
          <!-- Like ChatGPT: on hover the ⋯ menu and a new chat in this project show over the end of the row, so
               nothing moves. -->
          <div
            :class="project.id === dropTargetId ? 'from-tint' : 'from-surface'"
            class="absolute inset-y-0 right-0 flex items-center rounded-r-md bg-linear-to-l from-70% to-transparent pl-5 opacity-100 md:opacity-0 md:group-hover:opacity-100 md:group-focus-within:opacity-100"
          >
            <AylaRowMenu
              floats
              :items="menuItemsFor(project)"
              :label="`${AYLA_MORE_OPTIONS}: ${project.name}`"
              @select="handleMenuChoice(project, $event)"
            />
            <button
              type="button"
              class="flex size-7 items-center justify-center rounded-lg text-brand hover:text-ink focus-visible:outline-2 focus-visible:outline-brand"
              :title="AYLA_PROJECT_NEW_CHAT"
              @click="startChat(project.id)"
            >
              <LayoutPaveIcon name="compose" class="size-3.5" />
              <span class="sr-only">{{ `${AYLA_PROJECT_NEW_CHAT}: ${project.name}` }}</span>
            </button>
          </div>
        </div>

        <ul v-if="isOpen(project.id)" class="mb-1 mt-0.5 space-y-0.5 pl-4">
          <AylaChatRow
            v-for="conversation in chatsOf(project.id)"
            :key="conversation.id"
            :conversation="conversation"
            :is-active="conversation.id === activeChatId"
            :can-pin="canPin"
            :now="now"
            @open="emit('open')"
            @toggle-pin="emit('togglePin', conversation)"
            @rename="emit('rename', conversation, $event)"
            @remove="emit('remove', conversation)"
            @lock="emit('lock', conversation)"
          />
        </ul>
      </li>
      <li v-if="hasLockedChats">
        <div class="group relative -mx-2 flex items-center rounded-md hover:bg-surface">
          <button
            type="button"
            :aria-expanded="isUnlocked ? isLockedOpen : undefined"
            class="flex min-w-0 flex-1 items-center gap-2 rounded-md px-2 py-1 text-left focus-visible:outline-2 focus-visible:outline-brand"
            :class="{ 'max-md:pr-18': isUnlocked }"
            @click="toggleLocked"
          >
            <LayoutPaveIcon :name="isUnlocked ? 'lockOpen' : 'lock'" class="size-4 shrink-0 text-brand" />
            <span class="min-w-0 flex-1 truncate text-sm font-medium text-heading">{{ AYLA_LOCKED_CHATS }}</span>
          </button>
          <div
            v-if="isUnlocked"
            class="from-surface absolute inset-y-0 right-0 flex items-center rounded-r-md bg-linear-to-l from-70% to-transparent pl-5 opacity-100 md:opacity-0 md:group-hover:opacity-100 md:group-focus-within:opacity-100"
          >
            <AylaRowMenu
              floats
              :items="lockedMenuItems"
              :label="`${AYLA_MORE_OPTIONS}: ${AYLA_LOCKED_CHATS}`"
              @select="handleLockedChoice"
            />
            <button
              type="button"
              class="flex size-7 items-center justify-center rounded-lg text-brand hover:text-ink focus-visible:outline-2 focus-visible:outline-brand"
              :title="AYLA_LOCKED_NEW_CHAT"
              @click="handleLockedChoice('new')"
            >
              <LayoutPaveIcon name="compose" class="size-3.5" />
              <span class="sr-only">{{ AYLA_LOCKED_NEW_CHAT }}</span>
            </button>
          </div>
        </div>
        <ul v-if="isUnlocked && isLockedOpen" class="mb-1 mt-0.5 space-y-0.5 pl-4">
          <AylaChatRow
            v-for="conversation in lockedChats"
            :key="conversation.id"
            :conversation="conversation"
            :is-active="conversation.id === activeChatId"
            :can-pin="false"
            :now="now"
            @open="emit('open')"
            @rename="emit('rename', conversation, $event)"
            @remove="emit('remove', conversation)"
          />
        </ul>
      </li>
    </ul>

    <p
      v-if="projects.state.value.notice"
      :role="projects.state.value.notice.isError ? 'alert' : 'status'"
      :class="projects.state.value.notice.isError ? 'text-danger' : 'text-subtle'"
      class="mt-2 text-xs"
    >
      {{ projects.state.value.notice.text }}
    </p>
    <p v-if="rowError" role="alert" class="mt-2 text-xs text-danger">{{ rowError }}</p>
    <p
      v-if="dropMessage"
      :role="dropMessage.isError ? 'alert' : 'status'"
      :class="dropMessage.isError ? 'text-danger' : 'text-subtle'"
      class="mt-2 text-xs"
    >
      {{ dropMessage.text }}
    </p>

    <AylaProjectEditor
      v-if="isCreating"
      :title="AYLA_NEW_PROJECT"
      :confirm-label="AYLA_PROJECT_CREATE"
      initial-name=""
      initial-instructions=""
      :error="error"
      @save="create"
      @close="isCreating = false"
    />
    <AylaProjectEditor
      v-if="editing"
      :title="AYLA_PROJECT_SETTINGS"
      :confirm-label="AYLA_SAVE"
      :initial-name="editing.name"
      :initial-instructions="editing.instructions"
      :error="editError"
      @save="saveSettings"
      @close="editing = null"
    />
    <LayoutConfirmSheet
      ref="deleteConfirm"
      :title="AYLA_PROJECT_DELETE_QUESTION"
      :message="AYLA_PROJECT_DELETE_BODY"
      :confirm-label="AYLA_DELETE"
      @confirm="confirmDelete"
    />
    <AylaPinDialog
      v-if="isAskingPin"
      mode="enter"
      :error="pinError"
      :is-busy="isCheckingPin"
      @complete="checkPin"
      @forgot="resetRef?.open()"
      @close="isAskingPin = false"
    />
    <LayoutConfirmSheet
      ref="resetConfirm"
      :title="AYLA_PIN_RESET_QUESTION"
      :message="AYLA_PIN_RESET_BODY"
      :confirm-label="AYLA_PIN_RESET_CONFIRM"
      @confirm="resetPin"
    />
  </section>
</template>
