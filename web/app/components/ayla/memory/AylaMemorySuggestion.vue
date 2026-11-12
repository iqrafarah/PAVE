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
    class="mt-3 rounded-2xl border border-line bg-white p-4"
  >
    <h3 :id="headingId" class="text-sm font-semibold text-ink">{{ heading }}</h3>
    <ul class="mt-3 space-y-2">
      <li v-for="line in lines" :key="line.id">
        <label class="flex cursor-pointer items-start gap-3 rounded-lg p-1 hover:bg-surface">
          <input
            v-model="line.isTicked"
            type="checkbox"
            class="mt-1 size-4 shrink-0 accent-brand"
            :disabled="status === 'saving'"
          />
          <span class="text-sm">
            <span :class="line.kind === 'remove' ? 'text-muted line-through' : 'text-ink'">{{ line.text }}</span>
            <span class="block text-xs text-muted">{{ getLineLabel(line) }}</span>
          </span>
        </label>
      </li>
    </ul>
    <p v-if="hasRemovalLine" class="mt-2 text-xs text-muted">{{ MEMORY_SUGGESTION_FOOTNOTE }}</p>
    <p v-if="error" role="alert" class="mt-2 text-sm text-danger">{{ error }}</p>
    <div class="mt-3 flex flex-wrap gap-2">
      <button
        type="button"
        :disabled="tickedLines.length === 0 || status === 'saving'"
        class="min-h-10 rounded-lg bg-brand px-4 text-sm font-medium text-white hover:bg-ink focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-brand disabled:cursor-not-allowed disabled:bg-line disabled:text-muted"
        @click="confirm"
      >
        {{ confirmLabel }}
      </button>
      <button
        type="button"
        :disabled="status === 'saving'"
        class="min-h-10 rounded-lg border border-line px-4 text-sm font-medium text-ink hover:bg-surface focus-visible:outline-2 focus-visible:outline-brand"
        @click="status = 'dismissed'"
      >
        {{ MEMORY_NOT_NEEDED }}
      </button>
    </div>
  </section>
  <p v-else-if="status === 'saved'" role="status" class="mt-3 text-sm text-muted">
    {{ MEMORY_SAVED }}
    <NuxtLink :to="MEMORY_PAGE_PATH" class="font-medium text-brand underline hover:text-ink">
      {{ MEMORY_SEE_ALL }}
    </NuxtLink>
  </p>
</template>
