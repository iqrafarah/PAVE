<script setup lang="ts">
import type { MemoryCategory, MemoryNote, RowMenuItem } from '~/types/ayla';

// A row in a folder (iOS AylaMemoryFolderScreen): the note, then who added it and when. Click it to change it;
// the menu has "Aanpassen" and "Vergeten" (on iOS the swipe actions and the context menu).
const props = defineProps<{
  note: MemoryNote;
  isEnabled: boolean;
  /** The folder it is shown in: its icon and tint go in front of the note. */
  category: MemoryCategory;
}>();

const emit = defineEmits<{
  edit: [];
  forget: [];
}>();

const MENU_ITEMS: RowMenuItem[] = [
  { id: 'edit', label: MEMORY_EDIT },
  { id: 'forget', label: MEMORY_FORGET, isDanger: true },
];

const style = computed(() => MEMORY_CATEGORY_STYLES[props.category]);
const sourceLine = computed(() => getNoteSourceLine(props.note.source, formatNoteDate(props.note.createdAt)));

function handleMenuChoice(id: string) {
  if (id === 'edit') emit('edit');
  if (id === 'forget') emit('forget');
}
</script>

<template>
  <li class="flex items-center gap-3 rounded-2xl border border-card-border bg-white py-3 pl-3.5 pr-2 hover:bg-surface">
    <span :class="style.tintClass" class="flex size-10 shrink-0 items-center justify-center rounded-xl text-brand" aria-hidden="true">
      <LayoutPaveIcon :name="style.icon" class="size-5" />
    </span>
    <button
      type="button"
      class="flex min-w-0 flex-1 flex-col gap-0.5 rounded-lg py-1 text-left focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-brand"
      @click="emit('edit')"
    >
      <span translate="no" :class="isEnabled ? 'text-heading' : 'text-subtle'" class="break-words text-sm font-medium leading-snug">
        {{ note.text }}
      </span>
      <span class="text-xs/normal text-subtle">{{ sourceLine }}</span>
      <span class="sr-only">, {{ MEMORY_EDIT }}</span>
    </button>
    <AylaRowMenu :items="MENU_ITEMS" :label="`${AYLA_MORE_OPTIONS}: ${note.text}`" @select="handleMenuChoice" />
  </li>
</template>
