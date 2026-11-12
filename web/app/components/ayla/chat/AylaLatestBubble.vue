<script setup lang="ts">
import type { ChatMessage } from '~/types/ayla';

// Ayla's newest message, just above the composer (Figma "Kluis doorzoeken" and "Geen resultaat").
const props = defineProps<{
  message: ChatMessage;
  canAnswerAgain: boolean;
  // The question with choices under this answer, if any.
  question?: string;
}>();

// Ayla's question goes under her answer, as in the design ("…Wil je iets toevoegen?"), unless she already said it.
const shownText = computed(() => {
  const question = props.question?.trim();
  if (!question || props.message.isWriting || props.message.text.includes(question)) return props.message.text;
  return `${props.message.text}\n\n${question}`;
});

const emit = defineEmits<{
  answerAgain: [];
}>();
</script>

<template>
  <div class="group w-full max-w-135 animate-rise motion-reduce:animate-none">
    <AylaMessageActions
      v-if="!message.isWriting"
      :text="message.text"
      :can-answer-again="canAnswerAgain"
      :read-aloud-id="message.id"
      is-aligned-right
      is-above
      @answer-again="emit('answerAgain')"
    />
    <div class="flex max-h-40 gap-2 overflow-y-auto rounded-bubble bg-tint px-4.5 py-3">
      <AylaSlashIcon :blocks="4" class="mt-0.5 h-4 w-2.5" />
      <p class="min-w-0 flex-1 whitespace-pre-wrap break-words text-xs font-semibold text-brand">
        <span class="sr-only">{{ AYLA_NAME }}:</span>
        {{ shownText }}
      </p>
    </div>
  </div>
</template>
