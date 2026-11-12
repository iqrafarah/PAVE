<script setup lang="ts">
import type { VaultItem } from '~/types/vault';

// The … menu of a card (iOS VaultItemActionButtons, there on a long press): Aanpassen, Bevestiging aanvragen, In mappen
// and Verwijderen. As on iOS, "In mappen" is a menu of its own that opens beside the first one: every folder is ticked
// on or off and both stay open meanwhile, since an item can be in several folders. (On a phone there is no room beside
// it, so the folders show under the row.) The list is placed on the screen itself and opens upwards when
// there is no room below, so a card at the bottom or a row in the list never cuts it off.
const props = defineProps<{
  item: VaultItem;
}>();

const emit = defineEmits<{
  select: [id: 'edit' | 'confirm' | 'delete'];
}>();

const vault = useVault();
const isOpen = ref(false);
const showsFolders = ref(false);
const rootRef = useTemplateRef<HTMLDivElement>('root');
const toggleRef = useTemplateRef<HTMLButtonElement>('toggle');
const menuRef = useTemplateRef<HTMLDivElement>('menu');
const menuId = useId();
const foldersId = useId();
const floatingStyle = ref<Record<string, string>>({});
const foldersRowRef = useTemplateRef<HTMLDivElement>('foldersRow');
// The folder menu hangs down from its row, or stands on it when there is no room below.
const foldersOpenUp = ref(false);
// It opens on the left of the menu (the … button is at the right of a card), or on the right without room there.
const foldersOnRight = ref(false);

/** The button or the list: the list is moved to the end of the page, so nothing on the page can end up on top of it. */
function holds(node: Node | null) {
  return Boolean(node && (rootRef.value?.contains(node) || menuRef.value?.contains(node)));
}

const hasFolders = computed(() => vault.shelves.value.length > 0);

/** Below the button when it fits, otherwise above it; never taller than the room there is. */
function place() {
  const rect = toggleRef.value?.getBoundingClientRect();
  if (!rect) return;
  const right = `${Math.max(8, window.innerWidth - rect.right)}px`;
  const height = (menuRef.value?.scrollHeight ?? 180) + 2;
  const below = window.innerHeight - rect.bottom - 12;
  const above = rect.top - 12;
  floatingStyle.value =
    height > below && above > below
      ? { position: 'fixed', bottom: `${window.innerHeight - rect.top + 4}px`, right }
      : { position: 'fixed', top: `${rect.bottom + 4}px`, right };
}

function getItems() {
  return Array.from(menuRef.value?.querySelectorAll<HTMLElement>('[role^="menuitem"]') ?? []);
}

async function open() {
  showsFolders.value = false;
  place();
  isOpen.value = true;
  await nextTick();
  place();
  getItems()[0]?.focus();
}

function close(isReturningFocus: boolean) {
  isOpen.value = false;
  if (isReturningFocus) toggleRef.value?.focus();
}

function choose(id: 'edit' | 'confirm' | 'delete') {
  close(true);
  emit('select', id);
}

function setFolders(isShown: boolean) {
  if (isShown === showsFolders.value) return;
  const top = foldersRowRef.value?.getBoundingClientRect().top ?? 0;
  const needed = Math.min(vault.shelves.value.length * 36 + 10, 288);
  foldersOnRight.value = (menuRef.value?.getBoundingClientRect().left ?? 999) < 240;
  foldersOpenUp.value = top + needed > window.innerHeight - 12 && top > window.innerHeight / 2;
  showsFolders.value = isShown;
}

/** With a mouse the folder menu is already open from hovering, so a click keeps it open; a tap opens and closes it. */
function clickFolders() {
  setFolders(window.matchMedia('(hover: hover)').matches ? true : !showsFolders.value);
}

function moveFocus(step: number) {
  const items = getItems();
  const index = items.findIndex((entry) => entry === document.activeElement);
  items[(index + step + items.length) % items.length]?.focus();
}

function handleKeydown(event: KeyboardEvent) {
  if (!isOpen.value) return;
  if (event.key === 'Escape') close(true);
  else if (event.key === 'ArrowDown') moveFocus(1);
  else if (event.key === 'ArrowUp') moveFocus(-1);
  else return;
  event.preventDefault();
  event.stopPropagation();
}

function handleFocusOut(event: FocusEvent) {
  if (!holds(event.relatedTarget as Node | null)) isOpen.value = false;
}

function handlePointerDown(event: PointerEvent) {
  if (!holds(event.target as Node)) isOpen.value = false;
}

// The page or a row moving away would leave the list behind; scrolling inside the list itself is fine.
function closeOnScroll(event: Event) {
  if (holds(event.target as Node)) return;
  isOpen.value = false;
}

function listen(isOn: boolean) {
  const change = isOn ? window.addEventListener : window.removeEventListener;
  change('scroll', closeOnScroll, true);
  change('resize', closeOnScroll);
  (isOn ? document.addEventListener : document.removeEventListener)('pointerdown', handlePointerDown as EventListener);
}

watch(isOpen, listen);
onBeforeUnmount(() => listen(false));

const row =
  'flex min-h-9 w-full cursor-pointer items-center gap-2.5 rounded-lg px-3 text-left text-sm hover:bg-surface focus-visible:bg-surface focus-visible:outline-2 focus-visible:outline-brand';
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
      <span class="sr-only">{{ VAULT_ITEM_ACTIONS(item.title) }}</span>
    </button>
    <Teleport to="body">
      <div
        v-if="isOpen"
        :id="menuId"
        ref="menu"
        role="menu"
        :aria-label="VAULT_ITEM_ACTIONS(item.title)"
        :style="floatingStyle"
        class="z-50 w-56 rounded-xl border border-line bg-white p-1 shadow-lg"
        @focusout="handleFocusOut"
        @keydown="handleKeydown"
      >
        <button type="button" role="menuitem" :class="row" class="text-ink" @mouseenter="setFolders(false)" @click="choose('edit')">
          <VaultIcon src="/images/vault/icons/PencilOutline.svg" class="size-4.5 text-subtle" />
          {{ VAULT_EDIT }}
        </button>
        <!-- Confirmed evidence needs no request; anything else can be sent to a school or employer. -->
        <button v-if="item.status !== 'verified'" type="button" role="menuitem" :class="row" class="text-ink" @mouseenter="setFolders(false)" @click="choose('confirm')">
          <VaultIcon src="/images/vault/icons/CheckBadgeOutline.svg" class="size-4.5 text-subtle" />
          {{ VAULT_REQUEST_ACTION }}
        </button>
        <div v-if="hasFolders" ref="foldersRow" class="relative" @mouseenter="setFolders(true)">
          <button
            type="button"
            role="menuitem"
            aria-haspopup="menu"
            :aria-expanded="showsFolders"
            :aria-controls="showsFolders ? foldersId : undefined"
            :class="[row, showsFolders ? 'bg-surface' : '']"
            class="text-ink"
            @click="clickFolders"
            @keydown.right.prevent="setFolders(true)"
            @keydown.left.prevent="setFolders(false)"
          >
            <VaultIcon src="/images/vault/icons/FolderOutline.svg" class="size-4.5 text-subtle" />
            <span class="flex-1">{{ VAULT_IN_FOLDERS }}</span>
            <LayoutPaveIcon name="chevronDown" :class="foldersOnRight ? 'sm:-rotate-90' : 'sm:rotate-90'" class="size-3 text-subtle max-sm:hidden" />
          </button>
          <div
            v-if="showsFolders"
            :id="foldersId"
            role="menu"
            :aria-label="VAULT_IN_FOLDERS"
            :class="[foldersOpenUp ? 'sm:-bottom-1' : 'sm:-top-1', foldersOnRight ? 'sm:left-full sm:ml-1.5' : 'sm:right-full sm:mr-1.5']"
            class="max-h-72 overflow-y-auto max-sm:mb-1 max-sm:ml-3 max-sm:border-l max-sm:border-line max-sm:pl-1 sm:absolute sm:w-56 sm:rounded-xl sm:border sm:border-line sm:bg-white sm:p-1 sm:shadow-lg"
          >
            <button
              v-for="entry in vault.shelves.value"
              :key="entry.folder.id"
              type="button"
              role="menuitemcheckbox"
              :aria-checked="item.folderIds.includes(entry.folder.id)"
              :class="row"
              class="text-ink"
              @click="vault.toggleFolder(item, entry.folder.id)"
            >
              <span
                :class="item.folderIds.includes(entry.folder.id) ? 'border-brand bg-brand text-white' : 'border-field-line bg-white'"
                class="flex size-4 shrink-0 items-center justify-center rounded border"
                aria-hidden="true"
              >
                <LayoutPaveIcon v-if="item.folderIds.includes(entry.folder.id)" name="check" class="size-3" />
              </span>
              <span class="min-w-0 flex-1 truncate">{{ entry.folder.name }}</span>
            </button>
          </div>
        </div>
        <button type="button" role="menuitem" :class="row" class="text-danger" @mouseenter="setFolders(false)" @click="choose('delete')">
          <VaultIcon src="/images/vault/icons/TrashOutline.svg" class="size-4.5" />
          {{ VAULT_DELETE }}
        </button>
      </div>
    </Teleport>
  </div>
</template>
