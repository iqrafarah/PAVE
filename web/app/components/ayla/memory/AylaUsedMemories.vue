<script setup lang="ts">
import type { UsedMemory } from '~/types/ayla';

// Under Ayla's answer (iOS AylaUsedMemories): what it leans on from what she remembers about you, as PAVE promises.
// One quiet line; click it for a small card with the notes themselves. Escape or a click outside closes it.
const props = defineProps<{
  memories: UsedMemory[];
  messageId: string;
}>();

const isOpen = ref(false);
const rootRef = useTemplateRef<HTMLDivElement>('root');
const toggleRef = useTemplateRef<HTMLButtonElement>('toggle');

const titles = computed(() => getUsedCategoryTitles(props.memories.map((memory) => memory.category)));
const line = computed(() => getUsedMemoriesLine(titles.value));
const detailsId = computed(() => `used-memories-${props.messageId}`);

function close(isReturningFocus: boolean) {
  isOpen.value = false;
  if (isReturningFocus) toggleRef.value?.focus();
}

function handleFocusOut(event: FocusEvent) {
  if (!rootRef.value?.contains(event.relatedTarget as Node | null)) isOpen.value = false;
}

function handleOutsideClick(event: MouseEvent) {
  if (!rootRef.value?.contains(event.target as Node)) isOpen.value = false;
}

onMounted(() => document.addEventListener('click', handleOutsideClick));
onBeforeUnmount(() => document.removeEventListener('click', handleOutsideClick));
</script>

<template>
  <div ref="root" class="relative mt-2" @focusout="handleFocusOut" @keydown.esc="close(true)">
    <button
      ref="toggle"
      type="button"
      :aria-expanded="isOpen"
      :aria-controls="isOpen ? detailsId : undefined"
      class="flex min-h-7 max-w-full items-center gap-1.5 rounded-lg pl-1 pr-2 text-xs/normal text-subtle hover:text-heading focus-visible:outline-2 focus-visible:outline-brand"
      @click="isOpen = !isOpen"
    >
      <AylaSlashIcon :blocks="4" class="h-3 w-1.75" />
      <span class="truncate">{{ line }}</span>
    </button>
    <div
      v-if="isOpen"
      :id="detailsId"
      role="group"
      :aria-label="MEMORY_USED_HEADING"
      class="absolute left-0 top-full z-30 mt-1 flex w-72.5 max-w-full flex-col gap-3 rounded-2xl border border-card-border bg-white p-4 shadow-lg"
    >
      <p class="text-sm font-semibold text-heading">{{ MEMORY_USED_HEADING }}</p>
      <ul class="flex flex-col gap-3">
        <li v-for="memory in memories" :key="memory.text" class="flex items-start gap-2.5">
          <span
            :class="MEMORY_CATEGORY_STYLES[memory.category].tintClass"
            class="flex size-6 shrink-0 items-center justify-center rounded-md text-brand"
            :title="getCategoryTitle(memory.category)"
          >
            <LayoutPaveIcon :name="MEMORY_CATEGORY_STYLES[memory.category].icon" class="size-3.25" />
            <span class="sr-only">{{ getCategoryTitle(memory.category) }}:</span>
          </span>
          <span class="min-w-0 break-words text-sm font-medium text-heading">{{ memory.text }}</span>
        </li>
      </ul>
      <NuxtLink
        :to="MEMORY_PAGE_PATH"
        class="flex min-h-9 items-center self-start rounded-lg text-sm font-semibold text-brand hover:underline focus-visible:outline-2 focus-visible:outline-brand"
      >
        {{ MEMORY_SEE_ALL }}
      </NuxtLink>
    </div>
  </div>
</template>
