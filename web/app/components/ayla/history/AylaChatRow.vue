<script setup lang="ts">
import type { Conversation, RowMenuItem } from '~/types/ayla';

const props = defineProps<{
  conversation: Conversation;
  isActive: boolean;
  canPin: boolean;
  now: Date;
}>();

const emit = defineEmits<{
  togglePin: [];
  rename: [title: string];
  remove: [];
  lock: [];
  open: [];
}>();

const isRenaming = ref(false);
const newTitle = ref('');
const renameInputRef = useTemplateRef<HTMLInputElement>('renameInput');

const lock = useAylaChatLock();
const projects = useAylaProjects();
// Only chats begun on the iPhone say where; chats from the web say nothing, and the watch stays hidden for now.
const isStartedOnPhone = computed(() => props.conversation.startedOn === 'phone');

// Like ChatGPT: what you do with the chat itself first, where it goes after that, delete last and in red.
// A locked chat (under Vergrendelde chats) only has rename, unlock and delete; it is not pinned, moved or dragged.
const isLocked = computed(() => lock.isLocked(props.conversation.id));

const menuItems = computed<RowMenuItem[]>(() => {
  if (isLocked.value) {
    return [
      { id: 'rename', label: AYLA_RENAME },
      { id: 'unlock', label: AYLA_UNLOCK_MENU },
      { id: 'remove', label: AYLA_DELETE, isDanger: true },
    ];
  }
  const items: RowMenuItem[] = [{ id: 'rename', label: AYLA_RENAME }];
  if (props.canPin) {
    items.push({ id: 'pin', label: props.conversation.pinnedAt ? AYLA_UNPIN : AYLA_PIN });
  }
  if (projects.state.value.status === 'ready') items.push({ id: 'move', label: AYLA_MOVE_TO_PROJECT, hasSubmenu: true });
  if (lock.isAvailable.value) items.push({ id: 'lock', label: AYLA_LOCK_MENU });
  items.push({ id: 'remove', label: AYLA_DELETE, isDanger: true });
  return items;
});

async function startRenaming() {
  newTitle.value = props.conversation.title;
  isRenaming.value = true;
  await nextTick();
  renameInputRef.value?.select();
}

// Dragging the chat onto a project in the list above puts it in that project.
function startDrag(event: DragEvent) {
  if (!event.dataTransfer) return;
  event.dataTransfer.setData(CHAT_DRAG_TYPE, props.conversation.id);
  event.dataTransfer.effectAllowed = 'move';
}

function finishRenaming() {
  if (!isRenaming.value) return;
  isRenaming.value = false;
  const title = newTitle.value.trim();
  if (title && title !== props.conversation.title) emit('rename', title);
}

async function unlock() {
  const { isFailed } = await lock.unlockChat(props.conversation.id);
  // Said under Projecten, where the locked chats are.
  if (isFailed) projects.showNotice(AYLA_UNLOCK_FAILED, true);
}

function handleMenuChoice(id: string) {
  if (id === 'pin') emit('togglePin');
  if (id === 'rename') startRenaming();
  if (id === 'lock') emit('lock');
  if (id === 'unlock') unlock();
  if (id === 'remove') emit('remove');
}
</script>

<template>
  <li
    class="group relative -mx-2 flex items-center rounded-md hover:bg-surface"
    :class="{ 'bg-tint': isActive }"
    :draggable="!isRenaming && !isLocked"
    @dragstart="startDrag"
  >
    <form v-if="isRenaming" class="flex-1 p-1" @submit.prevent="finishRenaming">
      <label :for="`rename-${conversation.id}`" class="sr-only">{{ AYLA_RENAME }}</label>
      <input
        :id="`rename-${conversation.id}`"
        ref="renameInput"
        v-model="newTitle"
        type="text"
        :maxlength="AYLA_MAX_TITLE_LENGTH"
        class="w-full rounded-md border border-brand bg-white px-2 py-1.5 text-sm text-ink focus-visible:outline-2 focus-visible:outline-brand"
        @blur="finishRenaming"
        @keydown.esc="isRenaming = false"
      />
    </form>
    <template v-else>
      <NuxtLink
        :to="`/ayla/${conversation.id}`"
        :aria-current="isActive ? 'page' : undefined"
        :title="conversation.title"
        class="flex min-w-0 flex-1 flex-col rounded-md px-2 py-1 max-md:pr-18 focus-visible:outline-2 focus-visible:outline-brand"
        @click="emit('open')"
        @dblclick.prevent="startRenaming"
      >
        <span class="flex items-baseline gap-2">
          <span class="min-w-0 flex-1 truncate text-sm font-medium text-heading">{{ conversation.title }}</span>
        </span>
        <span v-if="isStartedOnPhone" class="flex items-center gap-1 text-xs text-subtle">
          <VaultIcon src="/images/settings/phone.svg" class="size-3" />
          {{ AYLA_STARTED_ON_PHONE }}
        </span>
      </NuxtLink>
      <!-- On top of the end of the row, so showing it on hover never moves the title. -->
      <div
        :class="isActive ? 'from-tint' : 'from-surface'"
        class="absolute inset-y-0 right-0 flex items-center rounded-r-md bg-linear-to-l from-70% to-transparent pl-5 opacity-100 md:opacity-0 md:group-hover:opacity-100 md:group-focus-within:opacity-100"
      >
        <!-- Pin or unpin in one click, like ChatGPT. -->
        <button
          v-if="canPin && !isLocked"
          type="button"
          :aria-pressed="Boolean(conversation.pinnedAt)"
          :title="conversation.pinnedAt ? AYLA_UNPIN : AYLA_PIN"
          class="flex size-7 items-center justify-center rounded-lg text-brand hover:text-ink focus-visible:outline-2 focus-visible:outline-brand"
          @click="emit('togglePin')"
        >
          <LayoutPaveIcon name="pin" class="size-3.5" />
          <span class="sr-only">{{ conversation.pinnedAt ? AYLA_UNPIN : AYLA_PIN }}: {{ conversation.title }}</span>
        </button>
        <AylaRowMenu
          :items="menuItems"
          :label="`${AYLA_MORE_OPTIONS}: ${conversation.title}`"
          floats
          @select="handleMenuChoice"
        >
          <template #submenu="{ itemId, close }">
            <AylaMoveProjectPanel v-if="itemId === 'move'" :conversation="conversation" @done="close" />
          </template>
        </AylaRowMenu>
      </div>
    </template>
  </li>
</template>
