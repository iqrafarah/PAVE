<script setup lang="ts">
import type { Conversation } from '~/types/ayla';

// One group in the chat history: "Vastgezet", or when the chats were last used ("Vandaag", "Gisteren"…), as on iOS.
defineProps<{
  title: string;
  conversations: Conversation[];
  activeId: string | null;
  canPin: boolean;
  now: Date;
}>();

const emit = defineEmits<{
  open: [];
  togglePin: [conversation: Conversation];
  rename: [conversation: Conversation, title: string];
  remove: [conversation: Conversation];
}>();

const headingId = useId();
</script>

<template>
  <section :aria-labelledby="headingId">
    <h2 :id="headingId" class="text-xs font-medium text-subtle">{{ title }}</h2>
    <ul class="mt-2 space-y-0.5">
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
      />
    </ul>
  </section>
</template>
