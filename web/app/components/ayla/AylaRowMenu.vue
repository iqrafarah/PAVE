<script setup lang="ts">
import type { RowMenuItem } from '~/types/ayla';

defineProps<{
  items: RowMenuItem[];
  label: string;
}>();

const emit = defineEmits<{
  select: [id: string];
}>();

const isOpen = ref(false);
const rootRef = useTemplateRef<HTMLDivElement>('root');
const toggleRef = useTemplateRef<HTMLButtonElement>('toggle');
const menuId = useId();

function getMenuItems() {
  return Array.from(rootRef.value?.querySelectorAll<HTMLButtonElement>('[role="menuitem"]') ?? []);
}

async function open() {
  isOpen.value = true;
  await nextTick();
  getMenuItems()[0]?.focus();
}

function close(isReturningFocus: boolean) {
  isOpen.value = false;
  if (isReturningFocus) toggleRef.value?.focus();
}

function choose(id: string) {
  close(true);
  emit('select', id);
}

function moveFocus(step: number) {
  const items = getMenuItems();
  const currentIndex = items.findIndex((item) => item === document.activeElement);
  const nextIndex = (currentIndex + step + items.length) % items.length;
  items[nextIndex]?.focus();
}

function handleKeydown(event: KeyboardEvent) {
  if (event.key === 'Escape') close(true);
  else if (event.key === 'ArrowDown') moveFocus(1);
  else if (event.key === 'ArrowUp') moveFocus(-1);
  else return;
  event.preventDefault();
}

function handleFocusOut(event: FocusEvent) {
  const nextFocus = event.relatedTarget as Node | null;
  if (!rootRef.value?.contains(nextFocus)) isOpen.value = false;
}
</script>

<template>
  <div ref="root" class="relative" @focusout="handleFocusOut" @keydown="handleKeydown">
    <button
      ref="toggle"
      type="button"
      aria-haspopup="menu"
      :aria-expanded="isOpen"
      :aria-controls="isOpen ? menuId : undefined"
      class="flex size-8 items-center justify-center rounded-lg text-muted hover:bg-white hover:text-ink focus-visible:outline-2 focus-visible:outline-brand"
      @click="isOpen ? close(false) : open()"
    >
      <LayoutPaveIcon name="ellipsis" class="size-5" />
      <span class="sr-only">{{ label }}</span>
    </button>
    <ul
      v-if="isOpen"
      :id="menuId"
      role="menu"
      class="absolute right-0 top-full z-30 mt-1 w-48 rounded-xl border border-line bg-white p-1 shadow-lg"
    >
      <li v-for="item in items" :key="item.id" role="none">
        <button
          type="button"
          role="menuitem"
          :class="item.isDanger ? 'text-danger' : 'text-ink'"
          class="w-full rounded-lg px-3 py-2 text-left text-sm hover:bg-surface focus-visible:bg-surface focus-visible:outline-2 focus-visible:outline-brand"
          @click="choose(item.id)"
        >
          {{ item.label }}
        </button>
      </li>
    </ul>
  </div>
</template>
