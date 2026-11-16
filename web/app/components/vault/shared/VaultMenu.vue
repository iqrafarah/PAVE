<script setup lang="ts">
// A button above the vault that opens a short list. For Status, Bron and Datum the chosen option has a check, and
// choosing it again turns the filter off, so "Alle" needs no row of its own (as on iOS). For "Toevoegen" the rows are
// actions with an icon (iOS: the plus menu with "Item toevoegen" and "Map aanmaken").
import type { VaultMenuOption } from '~/types/vault';

const props = defineProps<{
  label: string;
  options: VaultMenuOption[];
  // What is chosen, read after the label by screen readers ("Status: Geverifieerd").
  summary?: string;
  align?: 'left' | 'right';
  // The look of the button; the label slot replaces the text.
  toggleClass: string;
}>();

const emit = defineEmits<{
  select: [id: string];
}>();

const isOpen = ref(false);
const rootRef = useTemplateRef<HTMLDivElement>('root');
const toggleRef = useTemplateRef<HTMLButtonElement>('toggle');
const menuId = useId();

const isChoice = computed(() => props.options.some((option) => option.isChecked !== undefined));

function getItems() {
  return Array.from(rootRef.value?.querySelectorAll<HTMLButtonElement>('[role="menuitemradio"], [role="menuitem"]') ?? []);
}

async function open() {
  isOpen.value = true;
  await nextTick();
  const items = getItems();
  (items.find((item) => item.getAttribute('aria-checked') === 'true') ?? items[0])?.focus();
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
  const items = getItems();
  const index = items.findIndex((item) => item === document.activeElement);
  items[(index + step + items.length) % items.length]?.focus();
}

function handleKeydown(event: KeyboardEvent) {
  if (!isOpen.value) return;
  if (event.key === 'Escape') close(true);
  else if (event.key === 'ArrowDown') moveFocus(1);
  else if (event.key === 'ArrowUp') moveFocus(-1);
  else return;
  event.preventDefault();
}

function handleFocusOut(event: FocusEvent) {
  if (!rootRef.value?.contains(event.relatedTarget as Node | null)) isOpen.value = false;
}

// A click anywhere else closes the list, also where nothing can take focus.
function handlePointerDown(event: PointerEvent) {
  if (isOpen.value && !rootRef.value?.contains(event.target as Node)) isOpen.value = false;
}

onMounted(() => document.addEventListener('pointerdown', handlePointerDown));
onBeforeUnmount(() => document.removeEventListener('pointerdown', handlePointerDown));
</script>

<template>
  <div ref="root" class="relative" @focusout="handleFocusOut" @keydown="handleKeydown">
    <button
      ref="toggle"
      type="button"
      aria-haspopup="menu"
      :aria-expanded="isOpen"
      :aria-controls="isOpen ? menuId : undefined"
      :class="toggleClass"
      @click="isOpen ? close(false) : open()"
    >
      <slot name="label">{{ label }}</slot>
      <span v-if="summary" class="sr-only">: {{ summary }}</span>
    </button>
    <div
      v-if="isOpen"
      :id="menuId"
      role="menu"
      :aria-label="label"
      :class="align === 'right' ? 'right-0' : 'left-0'"
      class="absolute top-full z-30 mt-2 w-56 rounded-xl border border-card-line bg-white p-1.5 shadow-modal"
    >
      <button
        v-for="option in options"
        :key="option.id"
        type="button"
        :role="isChoice ? 'menuitemradio' : 'menuitem'"
        :aria-checked="isChoice ? Boolean(option.isChecked) : undefined"
        class="flex min-h-10 w-full items-center gap-2.5 rounded-lg px-3 text-left text-sm font-medium text-heading hover:bg-surface focus-visible:bg-surface focus-visible:outline-2 focus-visible:outline-brand"
        @click="choose(option.id)"
      >
        <span v-if="isChoice" class="flex size-4 items-center justify-center text-brand">
          <LayoutPaveIcon v-if="option.isChecked" name="check" class="size-4" />
        </span>
        <VaultIcon v-else-if="option.icon" :src="option.icon" class="size-5 text-brand" />
        {{ option.label }}
      </button>
    </div>
  </div>
</template>
