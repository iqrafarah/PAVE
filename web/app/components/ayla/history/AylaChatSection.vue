<script setup lang="ts">
import type { Conversation } from '~/types/ayla';

// One group in the chat history: "Vastgezet", or when the chats were last used ("Vandaag", "Gisteren"…), as on iOS.
const props = defineProps<{
  title: string;
  conversations: Conversation[];
  activeId: string | null;
  canPin: boolean;
  now: Date;
  // Gives the heading a chevron that folds the group, remembered in this browser.
  collapseKey?: string;
}>();

const emit = defineEmits<{
  open: [];
  togglePin: [conversation: Conversation];
  rename: [conversation: Conversation, title: string];
  remove: [conversation: Conversation];
  lock: [conversation: Conversation];
}>();

const headingId = useId();
const listId = useId();
const isCollapsed = useCollapsed(props.collapseKey);
</script>

<template>
  <section :aria-labelledby="headingId">
    <h2 :id="headingId" class="text-xs font-medium text-subtle">
      <button
        v-if="collapseKey"
        type="button"
        :aria-expanded="!isCollapsed"
        :aria-controls="listId"
        class="-mx-1 flex items-center gap-1 rounded-md px-1 hover:text-heading focus-visible:outline-2 focus-visible:outline-brand"
        @click="isCollapsed = !isCollapsed"
      >
        {{ title }}
        <LayoutPaveIcon name="chevronRight" :class="isCollapsed ? '' : 'rotate-90'" class="size-2 transition-transform" />
      </button>
      <template v-else>{{ title }}</template>
    </h2>
    <ul v-show="!isCollapsed" :id="listId" class="mt-2 space-y-0.5">
      <AylaChatRow
        v-for="conversation in conversations"
        :key="conversation.id"
        :conversation="conversation"
        :is-active="conversation.id === activeId"
        :can-pin="canPin"
        :now="now"
        @open="emit('open')"
        @toggle-pin="emit('togglePin', conversation)"
        @rename="emit('rename', conversation, $event)"
        @remove="emit('remove', conversation)"
        @lock="emit('lock', conversation)"
      />
    </ul>
  </section>
</template>
