<script setup lang="ts">
import type { MemoryNote, RowMenuItem } from '~/types/ayla';

// A row in a folder (iOS AylaMemoryFolderScreen): the note, then who added it and when. Click it to change it;
// the menu has "Aanpassen" and "Vergeten" (on iOS the swipe actions and the context menu).
const props = defineProps<{
  note: MemoryNote;
  isEnabled: boolean;
}>();

const emit = defineEmits<{
  edit: [];
  forget: [];
}>();

const MENU_ITEMS: RowMenuItem[] = [
  { id: 'edit', label: MEMORY_EDIT },
  { id: 'forget', label: MEMORY_FORGET, isDanger: true },
];

const sourceLine = computed(() => getNoteSourceLine(props.note.source, formatNoteDate(props.note.createdAt)));

function handleMenuChoice(id: string) {
  if (id === 'edit') emit('edit');
  if (id === 'forget') emit('forget');
}
</script>

<template>
  <li class="flex items-center gap-1 pr-2">
    <button
      type="button"
      class="flex min-w-0 flex-1 flex-col gap-1 py-3.5 pl-4 text-left focus-visible:outline-2 focus-visible:-outline-offset-2 focus-visible:outline-brand"
      @click="emit('edit')"
    >
      <span :class="isEnabled ? 'text-heading' : 'text-subtle'" class="break-words text-sm font-medium">
        {{ note.text }}
      </span>
      <span class="text-xs/normal text-subtle">{{ sourceLine }}</span>
      <span class="sr-only">, {{ MEMORY_EDIT }}</span>
    </button>
    <AylaRowMenu :items="MENU_ITEMS" :label="`${AYLA_MORE_OPTIONS}: ${note.text}`" @select="handleMenuChoice" />
  </li>
</template>
