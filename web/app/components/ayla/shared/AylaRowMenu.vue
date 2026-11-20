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
const openMenu = useAylaOpenMenu();
const chats = useAylaChats();
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

let isCounted = false;
function release() {
  if (!isCounted) return;
  isCounted = false;
  openMenu.openCount.value -= 1;
  if (openMenu.openCount.value === 0 && openMenu.hasPendingReload.value) {
    openMenu.hasPendingReload.value = false;
    chats.load();
  }
}

watch(isOpen, (open) => {
  if (open && !isCounted) {
    isCounted = true;
    openMenu.openCount.value += 1;
  } else if (!open) release();
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
  release();
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
  getMenuItems()[0]?.focus({ preventScroll: true });
}

function close(isReturningFocus: boolean) {
  isOpen.value = false;
  submenuFor.value = null;
  if (isReturningFocus) toggleRef.value?.focus();
}

// A panel next to the menu, for an item with `hasSubmenu` (like "Voeg toe aan project" in Notion). It sits on the
// screen itself, so the list of a floating menu can be as wide as it needs to be.
const SUBMENU_WIDTH = 248;
const SUBMENU_MAX_HEIGHT = 340;
const submenuFor = ref<string | null>(null);
const submenuStyle = ref<Record<string, string>>({});

function openSubmenu(id: string, anchor: HTMLElement) {
  const rect = anchor.getBoundingClientRect();
  const hasRoomOnRight = rect.right + 4 + SUBMENU_WIDTH <= window.innerWidth;
  const left = hasRoomOnRight ? rect.right + 4 : Math.max(4, rect.left - 4 - SUBMENU_WIDTH);
  const top = Math.max(4, Math.min(rect.top - 6, window.innerHeight - SUBMENU_MAX_HEIGHT));
  submenuStyle.value = { position: 'fixed', left: `${left}px`, top: `${top}px`, width: `${SUBMENU_WIDTH}px` };
  submenuFor.value = id;
}

function closeSubmenu() {
  const owner = menuRef.value?.querySelector<HTMLElement>(`[data-submenu-owner="${submenuFor.value}"]`);
  submenuFor.value = null;
  owner?.focus({ preventScroll: true });
}

function hoverItem(item: { id: string; hasSubmenu?: boolean }, event: MouseEvent) {
  const row = event.currentTarget as HTMLElement;
  if (item.hasSubmenu) {
    openSubmenu(item.id, row);
    return;
  }
  // The panel (with its search field) may hold the focus; move it to this row first, or closing the panel drops the
  // focus to the page and the whole menu closes under the pointer.
  if (submenuFor.value) row.querySelector<HTMLElement>('[role="menuitem"]')?.focus({ preventScroll: true });
  submenuFor.value = null;
}

function choose(item: { id: string; hasSubmenu?: boolean }, event?: Event) {
  if (item.hasSubmenu) {
    if (submenuFor.value === item.id) submenuFor.value = null;
    else openSubmenu(item.id, event?.currentTarget as HTMLElement);
    return;
  }
  close(true);
  emit('select', item.id);
}

function moveFocus(step: number) {
  const items = getMenuItems();
  const currentIndex = items.findIndex((item) => item === document.activeElement);
  const nextIndex = (currentIndex + step + items.length) % items.length;
  items[nextIndex]?.focus({ preventScroll: true });
}

function handleKeydown(event: KeyboardEvent) {
  const focused = document.activeElement as HTMLElement | null;
  if (event.key === 'Escape' && submenuFor.value) {
    closeSubmenu();
  } else if (event.key === 'ArrowRight' && focused?.dataset.submenuOwner) openSubmenu(focused.dataset.submenuOwner, focused);
  else if (event.key === 'Escape') close(true);
  else if (event.key === 'ArrowDown') moveFocus(1);
  else if (event.key === 'ArrowUp') moveFocus(-1);
  else return;
  event.preventDefault();
  // The list hears the key first; the root must not handle it a second time.
  event.stopPropagation();
}

function handleFocusOut(event: FocusEvent) {
  if (holds(event.relatedTarget as Node | null)) return;
  // Focus lost to nowhere while the pointer is on the menu (a focused field removed, or Safari not focusing a clicked
  // button): keep the menu open, and keep the focus in it.
  if (!event.relatedTarget && menuRef.value?.matches(':hover')) {
    menuRef.value.focus({ preventScroll: true });
    return;
  }
  isOpen.value = false;
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
      class="flex size-7 items-center justify-center rounded-lg text-muted hover:text-ink focus-visible:outline-2 focus-visible:outline-brand"
      @click="isOpen ? close(false) : open()"
    >
      <LayoutPaveIcon name="ellipsis" class="size-4" />
      <span class="sr-only">{{ label }}</span>
    </button>
    <Teleport to="body" :disabled="!floats">
      <ul
        v-if="isOpen"
        :id="menuId"
        ref="menu"
        role="menu"
        tabindex="-1"
        :style="floats ? floatingStyle : undefined"
        :class="floats ? 'z-50' : 'absolute right-0 top-full z-30 mt-1'"
        class="w-max min-w-48 max-w-72 outline-none rounded-xl border border-line bg-white p-1 shadow-lg"
        @focusout="handleFocusOut"
        @keydown="handleKeydown"
      >
        <li v-for="item in items" :key="item.id" role="none" @mouseenter="hoverItem(item, $event)">
          <button
            type="button"
            role="menuitem"
            :aria-haspopup="item.hasSubmenu ? 'true' : undefined"
            :aria-expanded="item.hasSubmenu ? submenuFor === item.id : undefined"
            :data-submenu-owner="item.hasSubmenu ? item.id : undefined"
            :class="[item.isDanger ? 'text-danger' : 'text-ink', submenuFor === item.id ? 'bg-surface' : '']"
            class="flex w-full items-center justify-between gap-6 whitespace-nowrap rounded-lg px-3 py-2 text-left text-sm hover:bg-surface focus-visible:bg-surface focus-visible:outline-2 focus-visible:outline-brand"
            @click="choose(item, $event)"
          >
            {{ item.label }}
            <LayoutPaveIcon v-if="item.hasSubmenu" name="chevronRight" class="size-2 text-subtle" />
          </button>
          <div
            v-if="item.hasSubmenu && submenuFor === item.id"
            :style="submenuStyle"
            class="z-50 rounded-xl border border-line bg-white p-1 shadow-lg"
            @keydown.stop
            @keydown.esc.stop.prevent="closeSubmenu"
          >
            <slot name="submenu" :item-id="item.id" :close="() => close(true)" />
          </div>
        </li>
      </ul>
    </Teleport>
  </div>
</template>
