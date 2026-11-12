<script setup lang="ts">
import type { ChatMessage } from '~/types/ayla';

// The open conversation at the bottom of the chat history panel (Figma: below the line in the panel).
const BOTTOM_MARGIN = 40;

const props = defineProps<{
  messages: ChatMessage[];
  isWriting: boolean;
}>();

const emit = defineEmits<{
  editQuestion: [];
}>();

const scrollerRef = useTemplateRef<HTMLDivElement>('scroller');
const isAtBottom = ref(true);

const lastText = computed(() => props.messages.at(-1)?.text ?? '');
const lastQuestionId = computed(() => {
  const beforeLast = props.messages.at(-2);
  return beforeLast?.role === 'user' ? beforeLast.id : null;
});

function updateIsAtBottom() {
  const scroller = scrollerRef.value;
  if (!scroller) return;
  isAtBottom.value = scroller.scrollHeight - scroller.scrollTop - scroller.clientHeight <= BOTTOM_MARGIN;
}

function scrollToBottom() {
  const scroller = scrollerRef.value;
  if (!scroller) return;
  scroller.scrollTop = scroller.scrollHeight;
  isAtBottom.value = true;
}

// Follow the conversation while Ayla writes, unless the user scrolled up to read something.
async function followNewText() {
  if (!isAtBottom.value) return;
  await nextTick();
  scrollToBottom();
}

watch(() => [props.messages.length, lastText.value], followNewText);
onMounted(scrollToBottom);
</script>

<template>
  <div class="relative min-h-0 flex-1">
    <div ref="scroller" class="flex h-full flex-col overflow-y-auto px-4.75 pb-4" @scroll="updateIsAtBottom">
      <ol class="mt-auto flex flex-col gap-2.5 pt-4" aria-label="Berichten">
        <li
          v-for="message in messages"
          :key="message.id"
          :class="message.role === 'user' ? 'items-end' : 'items-start'"
          class="group flex flex-col"
        >
          <p
            v-if="message.role === 'user'"
            class="max-w-52.75 whitespace-pre-wrap break-words rounded-xl bg-bubble px-3.25 py-3 text-xs font-semibold text-heading"
          >
            <span class="sr-only">Jij:</span>
            {{ message.text }}
          </p>
          <p
            v-else
            class="flex max-w-48.75 gap-2 whitespace-pre-wrap break-words rounded-xl bg-tint px-3.25 py-3.5 text-xs font-semibold text-brand"
          >
            <AylaSlashIcon :blocks="4" class="h-3.25 w-2 shrink-0" />
            <span class="sr-only">{{ AYLA_NAME }}:</span>
            <span v-if="message.text" class="min-w-0">{{ message.text }}</span>
            <span v-else class="sr-only">{{ AYLA_THINKING }}</span>
          </p>
          <ul v-if="message.attachmentNames.length" class="mt-1 flex flex-wrap justify-end gap-1" aria-label="Bijlagen">
            <li v-for="name in message.attachmentNames" :key="name" class="max-w-full">
              <AylaAttachmentChip :name="name" />
            </li>
          </ul>
          <AylaMessageActions
            v-if="message.role === 'user' && message.id === lastQuestionId && !isWriting"
            :text="message.text"
            can-edit-question
            is-aligned-right
            @edit-question="emit('editQuestion')"
          />
        </li>
      </ol>
    </div>
    <button
      v-if="!isAtBottom"
      type="button"
      :aria-label="AYLA_SCROLL_DOWN"
      :title="AYLA_SCROLL_DOWN"
      class="absolute bottom-2 left-1/2 flex size-9 -translate-x-1/2 items-center justify-center rounded-full border border-rail-line bg-white text-heading shadow-sm hover:bg-surface focus-visible:outline-2 focus-visible:outline-brand"
      @click="scrollToBottom"
    >
      <LayoutPaveIcon name="arrowDown" class="size-4" />
    </button>
  </div>
</template>
