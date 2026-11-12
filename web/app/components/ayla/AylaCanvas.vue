<script setup lang="ts">
import type { ChatMessage } from '~/types/ayla';

const props = defineProps<{
  // Ayla's newest message; its cards and suggestions are shown here, the conversation itself in the history panel.
  latestAnswer: ChatMessage | null;
  isWriting: boolean;
  // Ayla is reading an attachment (or the composer is reading a file): the only time this panel shows a loader.
  isReadingFiles: boolean;
  conversationId: string | null;
}>();

const reply = computed(() => props.latestAnswer?.reply ?? null);
const vacancyBlocks = computed(() => getVacancyBlocks(reply.value));
const vacancies = computed(() => vacancyBlocks.value.flatMap((block) => block.items));
const hasEmptySearch = computed(() => vacancyBlocks.value.length > 0 && vacancies.value.length === 0);
const memorySuggestions = computed(() => reply.value?.memories ?? []);
// When Ayla offers to add evidence, the Ja/Nee bar under her answer is the way in, not a button in the middle.
const navigation = computed(() => (offersToAddEvidence(reply.value) ? null : (reply.value?.navigation ?? null)));
// "Gebaseerd op" (AylaUsedMemories) is not shown for now, at the product owner's request.
const hasExtras = computed(
  () => memorySuggestions.value.length > 0 || Boolean(navigation.value),
);
</script>

<template>
  <div class="relative flex min-h-0 flex-1 flex-col overflow-y-auto px-4 pb-6 sm:px-13.25">
    <AylaDataLoader v-if="isReadingFiles" class="-mx-4 h-full sm:-mx-13.25" />

    <template v-else-if="latestAnswer && !isWriting">
      <div v-if="hasEmptySearch" class="flex h-full items-center justify-center">
        <AylaPixelLoader mode="empty" :label="AYLA_NOTHING_FOUND" />
      </div>
      <ul v-if="vacancies.length" class="grid grid-cols-1 gap-5 pt-4 sm:grid-cols-2 lg:grid-cols-3">
        <li v-for="vacancy in vacancies" :key="vacancy.id">
          <AylaVacancyCard :vacancy="vacancy" />
        </li>
      </ul>
      <div v-if="hasExtras" class="mx-auto mt-6 max-w-135">
        <AylaNavigationButton v-if="navigation" :screen="navigation.screen" />
        <AylaMemorySuggestion
          v-if="memorySuggestions.length"
          :suggestions="memorySuggestions"
          :conversation-id="conversationId"
          :message-id="latestAnswer.id"
        />
      </div>
    </template>
  </div>
</template>
