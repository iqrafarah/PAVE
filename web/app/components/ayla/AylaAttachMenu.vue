<script setup lang="ts">
// The plus button in the chat field and what it adds to a message (iOS AylaAttachMenu): it opens upwards over the
// left side of the field. Items from the vault and plans can be added once those exist; until then the rows say why not.
const emit = defineEmits<{
  addFile: [];
}>();

interface AttachRow {
  id: string;
  label: string;
  note?: string;
  icon: string;
  width: number;
  height: number;
  isAvailable: boolean;
}

const ROWS: AttachRow[] = [
  { id: 'item', label: AYLA_ADD_ITEM_LABEL, note: AYLA_VAULT_EMPTY_NOTE, icon: '/images/ayla/add-item.svg', width: 18, height: 16, isAvailable: false },
  { id: 'plan', label: AYLA_ADD_PLAN_LABEL, note: AYLA_NO_PLAN_NOTE, icon: '/images/ayla/add-plan.svg', width: 17, height: 16, isAvailable: false },
  { id: 'file', label: AYLA_ADD_FILE_LABEL, icon: '/images/ayla/add-file.svg', width: 14.6, height: 15.6, isAvailable: true },
];

const isOpen = ref(false);
const rootRef = useTemplateRef<HTMLDivElement>('root');
const toggleRef = useTemplateRef<HTMLButtonElement>('toggle');
const menuId = useId();

function getMenuItems() {
  return Array.from(rootRef.value?.querySelectorAll<HTMLButtonElement>('[role="menuitem"]:not(:disabled)') ?? []);
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

function choose(row: AttachRow) {
  if (!row.isAvailable) return;
  close(true);
  if (row.id === 'file') emit('addFile');
}

function moveFocus(step: number) {
  const items = getMenuItems();
  const currentIndex = items.findIndex((item) => item === document.activeElement);
  items[(currentIndex + step + items.length) % items.length]?.focus();
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
  const nextFocus = event.relatedTarget as Node | null;
  if (!rootRef.value?.contains(nextFocus)) isOpen.value = false;
}

function handlePointerDown(event: PointerEvent) {
  if (isOpen.value && !rootRef.value?.contains(event.target as Node)) isOpen.value = false;
}

onMounted(() => document.addEventListener('pointerdown', handlePointerDown));
onBeforeUnmount(() => document.removeEventListener('pointerdown', handlePointerDown));
</script>

<template>
  <div ref="root" class="relative shrink-0" @focusout="handleFocusOut" @keydown="handleKeydown">
    <button
      ref="toggle"
      type="button"
      aria-haspopup="menu"
      :aria-expanded="isOpen"
      :aria-controls="isOpen ? menuId : undefined"
      :class="isOpen ? 'bg-surface' : 'hover:bg-surface'"
      class="flex size-7 items-center justify-center rounded-full focus-visible:outline-2 focus-visible:outline-brand"
      @click="isOpen ? close(false) : open()"
    >
      <img
        src="/images/ayla/plus.svg"
        alt=""
        width="17"
        height="17"
        :class="isOpen ? 'rotate-45' : ''"
        class="transition-transform motion-reduce:transition-none"
      />
      <span class="sr-only">{{ AYLA_ADD_TO_MESSAGE_LABEL }}</span>
    </button>
    <Transition
      enter-from-class="scale-30 opacity-0"
      leave-to-class="scale-30 opacity-0"
      enter-active-class="transition duration-150 ease-out motion-reduce:transition-none"
      leave-active-class="transition duration-100 ease-in motion-reduce:transition-none"
    >
      <ul
        v-if="isOpen"
        :id="menuId"
        role="menu"
        :aria-label="AYLA_ADD_TO_MESSAGE_LABEL"
        class="absolute bottom-full left-0 z-30 mb-3 flex w-63.75 origin-bottom-left flex-col gap-1.25 rounded-[25px] border border-white/60 bg-white/85 p-5 shadow-composer backdrop-blur-xl"
      >
        <li v-for="row in ROWS" :key="row.id" role="none">
          <button
            type="button"
            role="menuitem"
            :disabled="!row.isAvailable"
            :aria-disabled="!row.isAvailable"
            :class="row.isAvailable ? 'hover:bg-surface' : 'cursor-not-allowed opacity-55'"
            class="flex min-h-11 w-full items-center gap-1.5 rounded-2xl text-left focus-visible:outline-2 focus-visible:outline-brand"
            @click="choose(row)"
          >
            <span class="flex size-9.25 shrink-0 items-center justify-center rounded-full bg-surface">
              <img :src="row.icon" alt="" :width="row.width" :height="row.height" />
            </span>
            <span class="flex min-w-0 flex-col gap-px">
              <span class="text-sm font-medium text-ink">{{ row.label }}</span>
              <span v-if="row.note" class="text-xs text-muted">{{ row.note }}</span>
            </span>
          </button>
        </li>
      </ul>
    </Transition>
  </div>
</template>
