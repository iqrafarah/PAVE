<script setup lang="ts">
import type { Conversation } from '~/types/ayla';

// One group in the chat history (Figma: "Vastgezet", and "Chats" with a chevron to fold it).
const props = defineProps<{
  title: string;
  conversations: Conversation[];
  activeId: string | null;
  canPin: boolean;
  isFoldable?: boolean;
}>();

const emit = defineEmits<{
  open: [];
  togglePin: [conversation: Conversation];
  rename: [conversation: Conversation, title: string];
  remove: [conversation: Conversation];
}>();

const isOpen = ref(true);
const listId = useId();

const showsList = computed(() => !props.isFoldable || isOpen.value);
</script>

<template>
  <section>
    <h2 class="text-xs font-medium text-subtle">
      <button
        v-if="isFoldable"
        type="button"
        :aria-expanded="isOpen"
        :aria-controls="listId"
        class="inline-flex items-center gap-1 rounded-sm focus-visible:outline-2 focus-visible:outline-brand"
        @click="isOpen = !isOpen"
      >
        {{ title }}
        <LayoutPaveIcon
          name="chevronDown"
          :class="isOpen ? '' : '-rotate-90'"
          class="size-3.25 transition-transform motion-reduce:transition-none"
        />
      </button>
      <template v-else>{{ title }}</template>
    </h2>
    <ul v-if="showsList" :id="listId" class="mt-2 space-y-0.5">
      <AylaChatRow
        v-for="conversation in conversations"
        :key="conversation.id"
        :conversation="conversation"
        :is-active="conversation.id === activeId"
        :can-pin="canPin"
        @open="emit('open')"
        @toggle-pin="emit('togglePin', conversation)"
        @rename="emit('rename', conversation, $event)"
        @remove="emit('remove', conversation)"
      />
    </ul>
  </section>
</template>
