<script setup lang="ts">
const COPIED_VISIBLE_MS = 2000;

const props = defineProps<{
  text: string;
  canAnswerAgain?: boolean;
  canEditQuestion?: boolean;
  isAlignedRight?: boolean;
  // The buttons sit above the message instead of under it (Ayla's newest answer, so it stays close to the text field).
  isAbove?: boolean;
  // Shown without hovering, for the newest message.
  isAlwaysVisible?: boolean;
  // Ayla's answers can be read out loud (iOS "Voorlezen").
  readAloudId?: string;
}>();

const emit = defineEmits<{
  answerAgain: [];
  editQuestion: [];
}>();

const readAloud = useAylaReadAloud();
const isReading = computed(() => Boolean(props.readAloudId) && readAloud.playingId.value === props.readAloudId);
const isCopied = ref(false);
let copiedTimer: ReturnType<typeof setTimeout> | undefined;

async function copyText() {
  try {
    await navigator.clipboard.writeText(props.text);
    isCopied.value = true;
    clearTimeout(copiedTimer);
    copiedTimer = setTimeout(() => (isCopied.value = false), COPIED_VISIBLE_MS);
  } catch {
    isCopied.value = false;
  }
}

onBeforeUnmount(() => clearTimeout(copiedTimer));
</script>

<template>
  <!-- Like ChatGPT and Claude: a row of small icons right under the message. The newest message always shows it,
       older ones on hover and keyboard focus (always on touch screens). The row keeps its height, so nothing jumps. -->
  <div
    :class="[
      isAlignedRight ? 'justify-end' : 'justify-start',
      isAbove ? 'mb-0' : 'mt-0',
      isAlwaysVisible ? 'opacity-100' : 'opacity-100 md:opacity-0 md:group-hover:opacity-100 md:group-focus-within:opacity-100',
    ]"
    class="flex h-6 gap-0.5"
  >
    <button
      type="button"
      class="flex size-6 items-center justify-center rounded-lg text-brand hover:bg-surface hover:text-ink focus-visible:outline-2 focus-visible:outline-brand"
      :title="isCopied ? AYLA_COPIED : AYLA_COPY_LABEL"
      @click="copyText"
    >
      <LayoutIcon :name="isCopied ? 'check' : 'copy'" class="size-4" />
      <span class="sr-only">{{ isCopied ? AYLA_COPIED : AYLA_COPY_LABEL }}</span>
    </button>
    <button
      v-if="readAloudId"
      type="button"
      :aria-pressed="isReading"
      class="flex size-6 items-center justify-center rounded-lg text-brand hover:bg-surface hover:text-ink focus-visible:outline-2 focus-visible:outline-brand"
      :title="isReading ? READ_ALOUD_STOP : READ_ALOUD"
      @click="readAloud.toggle(readAloudId, text)"
    >
      <LayoutPaveIcon :name="isReading ? 'stop' : 'speakerWave'" class="size-4" />
      <span class="sr-only">{{ isReading ? READ_ALOUD_STOP : READ_ALOUD }}</span>
    </button>
    <button
      v-if="canAnswerAgain"
      type="button"
      class="flex size-6 items-center justify-center rounded-lg text-brand hover:bg-surface hover:text-ink focus-visible:outline-2 focus-visible:outline-brand"
      :title="AYLA_NEW_ANSWER_LABEL"
      @click="emit('answerAgain')"
    >
      <LayoutIcon name="redo" class="size-4" />
      <span class="sr-only">{{ AYLA_NEW_ANSWER_LABEL }}</span>
    </button>
    <button
      v-if="canEditQuestion"
      type="button"
      class="flex size-6 items-center justify-center rounded-lg text-brand hover:bg-surface hover:text-ink focus-visible:outline-2 focus-visible:outline-brand"
      :title="AYLA_EDIT_QUESTION_LABEL"
      @click="emit('editQuestion')"
    >
      <LayoutIcon name="pencil" class="size-4" />
      <span class="sr-only">{{ AYLA_EDIT_QUESTION_LABEL }}</span>
    </button>
    <span v-if="isCopied" role="status" class="sr-only">{{ AYLA_COPIED }}</span>
  </div>
</template>
