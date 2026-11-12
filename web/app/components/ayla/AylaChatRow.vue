<script setup lang="ts">
import type { Conversation, RowMenuItem } from '~/types/ayla';

const props = defineProps<{
  conversation: Conversation;
  isActive: boolean;
  canPin: boolean;
}>();

const emit = defineEmits<{
  togglePin: [];
  rename: [title: string];
  remove: [];
  open: [];
}>();

const isRenaming = ref(false);
const newTitle = ref('');
const renameInputRef = useTemplateRef<HTMLInputElement>('renameInput');

const menuItems = computed<RowMenuItem[]>(() => {
  const items: RowMenuItem[] = [];
  if (props.canPin) {
    items.push({ id: 'pin', label: props.conversation.pinnedAt ? AYLA_UNPIN : AYLA_PIN });
  }
  items.push({ id: 'rename', label: AYLA_RENAME });
  items.push({ id: 'remove', label: AYLA_DELETE, isDanger: true });
  return items;
});

async function startRenaming() {
  newTitle.value = props.conversation.title;
  isRenaming.value = true;
  await nextTick();
  renameInputRef.value?.select();
}

function finishRenaming() {
  if (!isRenaming.value) return;
  isRenaming.value = false;
  const title = newTitle.value.trim();
  if (title && title !== props.conversation.title) emit('rename', title);
}

function handleMenuChoice(id: string) {
  if (id === 'pin') emit('togglePin');
  if (id === 'rename') startRenaming();
  if (id === 'remove') emit('remove');
}
</script>

<template>
  <li class="group relative -mx-2 flex items-center rounded-md hover:bg-surface" :class="{ 'bg-tint': isActive }">
    <form v-if="isRenaming" class="flex-1 p-1" @submit.prevent="finishRenaming">
      <label :for="`rename-${conversation.id}`" class="sr-only">{{ AYLA_RENAME }}</label>
      <input
        :id="`rename-${conversation.id}`"
        ref="renameInput"
        v-model="newTitle"
        type="text"
        maxlength="200"
        class="w-full rounded-md border border-brand bg-white px-2 py-1.5 text-sm text-ink focus-visible:outline-2 focus-visible:outline-brand"
        @blur="finishRenaming"
        @keydown.esc="isRenaming = false"
      />
    </form>
    <template v-else>
      <NuxtLink
        :to="`/ayla/${conversation.id}`"
        :aria-current="isActive ? 'page' : undefined"
        class="min-w-0 flex-1 truncate rounded-md px-2 py-1 text-sm font-medium text-heading focus-visible:outline-2 focus-visible:outline-brand"
        @click="emit('open')"
      >
        {{ conversation.title }}
      </NuxtLink>
      <div class="opacity-100 md:opacity-0 md:group-hover:opacity-100 md:group-focus-within:opacity-100">
        <AylaRowMenu
          :items="menuItems"
          :label="`${AYLA_MORE_OPTIONS}: ${conversation.title}`"
          @select="handleMenuChoice"
        />
      </div>
    </template>
  </li>
</template>
