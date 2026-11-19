<script setup lang="ts">
import type { MemoryCategory, MemorySuggestion } from '~/types/ayla';

interface SuggestionLine {
  id: string;
  kind: 'remember' | 'remove';
  text: string;
  category: MemoryCategory;
  isTicked: boolean;
}

type CardStatus = 'waiting' | 'open' | 'saving' | 'saved' | 'dismissed';

const props = defineProps<{
  suggestions: MemorySuggestion[];
  conversationId: string | null;
  messageId: string;
}>();

const memory = useAylaMemory();
const lines = ref<SuggestionLine[]>([]);
const status = ref<CardStatus>('waiting');
const error = ref<string | null>(null);

const tickedLines = computed(() => lines.value.filter((line) => line.isTicked));
const hasTickedRemoval = computed(() => tickedLines.value.some((line) => line.kind === 'remove'));
const hasTickedFact = computed(() => tickedLines.value.some((line) => line.kind === 'remember'));
const hasRemovalLine = computed(() => lines.value.some((line) => line.kind === 'remove'));
const hasFactLine = computed(() => lines.value.some((line) => line.kind === 'remember'));
const headingId = computed(() => `memory-suggestion-${props.messageId}`);

const heading = computed(() => {
  if (hasRemovalLine.value && hasFactLine.value) return MEMORY_QUESTION_UPDATE;
  if (hasRemovalLine.value) return MEMORY_QUESTION_REMOVE;
  return MEMORY_QUESTION_REMEMBER;
});

const confirmLabel = computed(() => {
  if (hasTickedRemoval.value && hasTickedFact.value) return MEMORY_UPDATE;
  if (hasTickedRemoval.value) return MEMORY_REMOVE;
  return MEMORY_REMEMBER;
});

function toLines(suggestions: MemorySuggestion[]) {
  const result: SuggestionLine[] = [];
  suggestions.forEach((suggestion, index) => {
    if (suggestion.replaces) {
      const id = `remove-${index}`;
      result.push({ id, kind: 'remove', text: suggestion.replaces, category: suggestion.category, isTicked: true });
    }
    if (suggestion.text) {
      const id = `remember-${index}`;
      result.push({ id, kind: 'remember', text: suggestion.text, category: suggestion.category, isTicked: true });
    }
  });
  return result;
}

// The lines are fixed once the notes are known, so saving does not make the card disappear mid-way.
function prepareLines() {
  if (status.value !== 'waiting' || memory.state.value.status !== 'ready') return;
  lines.value = toLines(memory.getOpenSuggestions(props.suggestions));
  status.value = lines.value.length ? 'open' : 'dismissed';
}

function getLineLabel(line: SuggestionLine) {
  if (line.kind === 'remove') return getRemoveFromCategoryLabel(getCategoryTitle(line.category));
  return getCategoryTitle(line.category);
}

async function confirm() {
  error.value = null;
  status.value = 'saving';
  const facts = tickedLines.value
    .filter((line) => line.kind === 'remember')
    .map((line) => ({ text: line.text, category: line.category }));
  const notesToRemove = tickedLines.value.filter((line) => line.kind === 'remove').map((line) => line.text);

  const { isFailed } = await memory.applySuggestions(facts, notesToRemove, props.conversationId);
  if (isFailed) {
    error.value = AYLA_MEMORY_SAVE_FAILED;
    status.value = 'open';
    return;
  }
  status.value = 'saved';
}

watch(() => memory.state.value.status, prepareLines, { immediate: true });
</script>

<template>
  <section
    v-if="status === 'open' || status === 'saving'"
    :aria-labelledby="headingId"
    class="mt-3 flex flex-col gap-2.5 rounded-pill border border-card-border bg-white p-3 shadow-modal"
  >
    <h3 :id="headingId" class="flex items-center gap-2 font-heading text-base font-semibold text-heading">
      <LayoutAylaGlyph class="size-4 shrink-0 text-brand" />{{ heading }}</h3>
    <ul class="flex flex-col gap-1">
      <li v-for="line in lines" :key="line.id">
        <label class="flex cursor-pointer items-start gap-3 rounded-field p-2 hover:bg-tint">
          <input
            v-model="line.isTicked"
            type="checkbox"
            class="mt-1 size-4 shrink-0 accent-brand"
            :disabled="status === 'saving'"
          />
          <span class="text-sm/snug">
            <span :class="line.kind === 'remove' ? 'text-subtle line-through' : 'font-medium text-heading'">{{ line.text }}</span>
            <span class="block text-xs text-subtle">{{ getLineLabel(line) }}</span>
          </span>
        </label>
      </li>
    </ul>
    <p v-if="hasRemovalLine" class="text-xs/normal text-subtle">{{ MEMORY_SUGGESTION_FOOTNOTE }}</p>
    <p v-if="error" role="alert" class="text-sm text-danger">{{ error }}</p>
    <div class="flex flex-wrap gap-2">
      <button
        type="button"
        :disabled="tickedLines.length === 0 || status === 'saving'"
        class="min-h-10 rounded-field bg-brand px-4 text-sm font-medium text-white hover:bg-ink focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-brand disabled:cursor-not-allowed disabled:bg-field-line disabled:text-subtle"
        @click="confirm"
      >
        {{ confirmLabel }}
      </button>
      <button
        type="button"
        :disabled="status === 'saving'"
        class="min-h-10 rounded-field bg-field-line px-4 text-sm font-medium text-heading hover:bg-tile focus-visible:outline-2 focus-visible:outline-brand"
        @click="status = 'dismissed'"
      >
        {{ MEMORY_NOT_NEEDED }}
      </button>
    </div>
  </section>
  <p v-else-if="status === 'saved'" role="status" class="mt-3 text-sm font-medium text-subtle">
    {{ MEMORY_SAVED }}
    <NuxtLink :to="MEMORY_PAGE_PATH" class="font-medium text-brand underline hover:text-ink">
      {{ MEMORY_SEE_ALL }}
    </NuxtLink>
  </p>
</template>
