<script setup lang="ts">
import type { RowMenuItem } from '~/types/ayla';

const props = defineProps<{
  items: RowMenuItem[];
  label: string;
  // The list is placed on the screen itself (position: fixed, and moved to the end of the page), so a parent that
  // scrolls, clips, fades or stays in place, like the sideways folder row in the vault, neither cuts it off nor ends
  // up on top of it. It closes when the page scrolls, as it would drift away.
  floats?: boolean;
}>();

const emit = defineEmits<{
  select: [id: string];
}>();

const isOpen = ref(false);
const rootRef = useTemplateRef<HTMLDivElement>('root');
const toggleRef = useTemplateRef<HTMLButtonElement>('toggle');
const menuRef = useTemplateRef<HTMLUListElement>('menu');

/** The button or the list: the list of a floating menu is not inside the root any more. */
function holds(node: Node | null) {
  return Boolean(node && (rootRef.value?.contains(node) || menuRef.value?.contains(node)));
}
const menuId = useId();
const floatingStyle = ref<Record<string, string> | undefined>();

function place() {
  const rect = toggleRef.value?.getBoundingClientRect();
  if (!rect) return;
  const right = `${window.innerWidth - rect.right}px`;
  // Without room below (about 40px a row), the list opens upwards, so it is never half off the screen.
  const height = props.items.length * 40 + 12;
  floatingStyle.value =
    rect.bottom + height > window.innerHeight
      ? { position: 'fixed', bottom: `${window.innerHeight - rect.top + 4}px`, right }
      : { position: 'fixed', top: `${rect.bottom + 4}px`, right };
}

function closeOnScroll(event: Event) {
  // Scrolling inside the list itself is fine; the page or a row moving away is not.
  if (holds(event.target as Node)) return;
  isOpen.value = false;
}

watch(isOpen, (open) => {
  if (!props.floats) return;
  if (open) {
    window.addEventListener('scroll', closeOnScroll, true);
    window.addEventListener('resize', closeOnScroll);
  } else {
    window.removeEventListener('scroll', closeOnScroll, true);
    window.removeEventListener('resize', closeOnScroll);
  }
});

onBeforeUnmount(() => {
  window.removeEventListener('scroll', closeOnScroll, true);
  window.removeEventListener('resize', closeOnScroll);
});

function getMenuItems() {
  return Array.from(menuRef.value?.querySelectorAll<HTMLButtonElement>('[role="menuitem"]') ?? []);
}

async function open() {
  if (props.floats) place();
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
  // The list hears the key first; the root must not handle it a second time.
  event.stopPropagation();
}

function handleFocusOut(event: FocusEvent) {
  if (!holds(event.relatedTarget as Node | null)) isOpen.value = false;
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
    <Teleport to="body" :disabled="!floats">
      <ul
        v-if="isOpen"
        :id="menuId"
        ref="menu"
        role="menu"
        :style="floats ? floatingStyle : undefined"
        :class="floats ? 'z-50' : 'absolute right-0 top-full z-30 mt-1'"
        class="w-48 rounded-xl border border-line bg-white p-1 shadow-lg"
        @focusout="handleFocusOut"
        @keydown="handleKeydown"
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
    </Teleport>
  </div>
</template>
