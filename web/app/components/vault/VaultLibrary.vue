<script setup lang="ts">
import type { RowMenuItem } from '~/types/ayla';
import type { VaultFilter, VaultFolder, VaultItem, VaultShelf } from '~/types/vault';

// Your vault (iOS VaultScreen, Figma 1209:55066 and 1209:53998): a row of folders on top that you can drag sideways,
// then everything in it as tiles or a list. The folders and the filter bar stay in place; only the evidence scrolls.
// On a low screen everything scrolls together. A folder opens on its own (?map= in the address, so the back button closes it
// again). Every folder, the four example folders too, can be changed or removed. It reads and writes your own
// Supabase rows; adding goes through "Kluis aanvullen".
const vault = useVault();
const route = useRoute();
const router = useRouter();
const vaultAdd = useVaultAdd();

const PAGE_SIZE = 9;
// Moved further than this, a press on the folder row is a drag and not a click on a folder.
const DRAG_DISTANCE = 6;
const primaryButton =
  'min-h-10 min-w-50 rounded-lg bg-brand px-4 text-sm font-medium text-white hover:bg-ink focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-brand';
const GRID_KEY = 'pave-vault-grid';

const filter = ref<VaultFilter>(createFilter());
const isGrid = ref(true);
const isSearching = ref(false);
const shelfRowRef = useTemplateRef<HTMLUListElement>('shelfRow');
const drag = ref<{ x: number; scrollLeft: number; isDragging: boolean } | null>(null);
const shownCount = ref(PAGE_SIZE);
const openedId = ref<string | null>(null);
const editedId = ref<string | null>(null);
const confirmedId = ref<string | null>(null);
// The evidence moved under the folders and the filter bar: a thin line then separates them.
const hasScrolled = ref(false);
// The folder row has more to the left or right: its edge fades there, so a folder never looks cut off.
const shelfFade = ref({ left: false, right: false });
const folderSheet = ref<VaultFolder | 'new' | null>(null);
const deletedFolder = ref<VaultFolder | null>(null);
const deletedItem = ref<VaultItem | null>(null);
const deleteFolderRef = useTemplateRef<{ open: () => void }>('confirmDeleteFolder');
const deleteItemRef = useTemplateRef<{ open: () => void }>('confirmDeleteItem');
const searchRef = useTemplateRef<HTMLInputElement>('search');
const searchId = useId();

const state = computed(() => vault.state.value);
const visibleItems = computed(() => applyFilter(state.value.items, filter.value));
const shownItems = computed(() => visibleItems.value.slice(0, shownCount.value));

const FOLDER_ACTIONS: RowMenuItem[] = [
  { id: 'edit', label: VAULT_FOLDER_EDIT },
  { id: 'delete', label: VAULT_FOLDER_DELETE, isDanger: true },
];

const shelfFolder = computed(() => (filter.value.shelf.kind === 'folder' ? vault.folder(filter.value.shelf.id) : null));
const openEntry = computed(() => vault.shelves.value.find((entry) => entry.folder.id === shelfFolder.value?.id) ?? null);

type EmptyKind = 'vault' | 'noResults' | 'folder';
const emptyKind = computed<EmptyKind | null>(() => {
  if (visibleItems.value.length) return null;
  if (!state.value.items.length) return 'vault';
  if (filter.value.searchText.trim() || narrowsDown(filter.value)) return 'noResults';
  return 'folder';
});

/** The folder in the address: the id of one of your folders. */
function shelfFromRoute(): VaultShelf {
  const map = typeof route.query.map === 'string' ? route.query.map : '';
  return map && vault.folder(map) ? { kind: 'folder', id: map } : { kind: 'all' };
}

function openFolder(folderId: string) {
  router.push({ query: { ...route.query, map: folderId } });
}

function closeShelf() {
  const { map: _, ...query } = route.query;
  router.push({ query });
}

/** New evidence goes in the folder you look at, and in the folder of its kind (as on iOS). */
function add() {
  vaultAdd.open({ folderId: shelfFolder.value?.id ?? null });
}

function clearFilters() {
  filter.value = createFilter();
}

function handleFolderAction(folder: VaultFolder, action: string) {
  if (action === 'edit') {
    folderSheet.value = folder;
    return;
  }
  deletedFolder.value = folder;
  deleteFolderRef.value?.open();
}

/** The items in the folder stay in the vault. */
async function deleteFolder() {
  const folder = deletedFolder.value;
  if (!folder) return;
  if (shelfFolder.value?.id === folder.id) closeShelf();
  await vault.deleteFolder(folder.id);
}

function folderCreated(folder: VaultFolder) {
  folderSheet.value = null;
  openFolder(folder.id);
}

// The folder row scrolls sideways by dragging it with the mouse, like swiping on a phone (touch already scrolls).
function startDrag(event: PointerEvent) {
  if (event.pointerType !== 'mouse' || event.button !== 0 || !shelfRowRef.value) return;
  drag.value = { x: event.clientX, scrollLeft: shelfRowRef.value.scrollLeft, isDragging: false };
}

function moveDrag(event: PointerEvent) {
  if (!drag.value || !shelfRowRef.value) return;
  const distance = event.clientX - drag.value.x;
  if (!drag.value.isDragging && Math.abs(distance) < DRAG_DISTANCE) return;
  if (!drag.value.isDragging) shelfRowRef.value.setPointerCapture(event.pointerId);
  drag.value.isDragging = true;
  shelfRowRef.value.scrollLeft = drag.value.scrollLeft - distance;
}

function endDrag() {
  // The click that ends a drag must not open the folder under the mouse; it is stopped in stopClickAfterDrag.
  if (!drag.value?.isDragging) drag.value = null;
  else setTimeout(() => (drag.value = null));
}

function stopClickAfterDrag(event: MouseEvent) {
  if (!drag.value?.isDragging) return;
  event.preventDefault();
  event.stopPropagation();
}

function updateShelfFade() {
  const row = shelfRowRef.value;
  if (!row) return;
  shelfFade.value = { left: row.scrollLeft > 1, right: row.scrollLeft + row.clientWidth < row.scrollWidth - 1 };
}

const shelfMask = computed(() => {
  const { left, right } = shelfFade.value;
  if (!left && !right) return undefined;
  const mask = `linear-gradient(to right, ${left ? 'transparent, black 2.5rem' : 'black, black'}, ${right ? 'black calc(100% - 2.5rem), transparent' : 'black'})`;
  return { maskImage: mask, WebkitMaskImage: mask };
});

function handleItemAction(item: VaultItem, action: 'edit' | 'confirm' | 'delete') {
  if (action === 'edit') editedId.value = item.id;
  else if (action === 'confirm') confirmedId.value = item.id;
  else {
    deletedItem.value = item;
    deleteItemRef.value?.open();
  }
}

async function deleteItem() {
  if (deletedItem.value) await vault.remove(deletedItem.value);
  deletedItem.value = null;
}

function editFromDetails(itemId: string) {
  openedId.value = null;
  editedId.value = itemId;
}

function confirmFromDetails(itemId: string) {
  openedId.value = null;
  confirmedId.value = itemId;
}

// The folders that fit depend on the width of the window and on how many there are.
watch(
  () => [vault.shelves.value.length, filter.value.shelf.kind, state.value.status],
  async () => {
    await nextTick();
    updateShelfFade();
  },
);


// The address says which folder is open; the folders you made are only known once the vault has loaded.
watch(
  () => [route.query.map, state.value.status, state.value.folders],
  () => {
    const shelf = shelfFromRoute();
    if (JSON.stringify(filter.value.shelf) !== JSON.stringify(shelf)) filter.value.shelf = shelf;
  },
  { immediate: true },
);

// A new filter starts at the top of the list again.
watch(
  () => [filter.value.shelf, filter.value.status, filter.value.origin, filter.value.order, filter.value.searchText],
  () => (shownCount.value = PAGE_SIZE),
  { deep: true },
);

watch(isSearching, async (searching) => {
  if (!searching) {
    filter.value.searchText = '';
    return;
  }
  await nextTick();
  searchRef.value?.focus();
});

// Grid or list is remembered on this device, like iOS (@AppStorage).
watch(isGrid, (value) => {
  try {
    localStorage.setItem(GRID_KEY, value ? 'grid' : 'list');
  } catch {
    // Without storage the choice is simply not remembered.
  }
});

onMounted(() => {
  try {
    isGrid.value = localStorage.getItem(GRID_KEY) !== 'list';
  } catch {
    isGrid.value = true;
  }
  vault.load();
  window.addEventListener('resize', updateShelfFade);
});

onBeforeUnmount(() => window.removeEventListener('resize', updateShelfFade));
</script>

<template>
  <div
    class="flex min-h-0 min-w-0 flex-1 flex-col overflow-y-auto overflow-x-hidden px-4 pb-40 sm:px-13.25"
    @scroll.passive="hasScrolled = ($event.target as HTMLElement).scrollTop > 1"
  >
    <div class="mx-auto flex w-full max-w-300 flex-col">
      <h2 class="sr-only">{{ VAULT_TITLE }}</h2>

      <!-- Loading: grey shapes where the folders and cards will appear. -->
      <div v-if="state.status === 'loading'" class="flex animate-pulse flex-col gap-6 pt-25.25 motion-reduce:animate-none" role="status">
        <span class="sr-only">{{ VAULT_LOADING }}</span>
        <div class="grid grid-cols-2 gap-3 sm:grid-cols-4" aria-hidden="true">
          <span v-for="index in 4" :key="index" class="h-27.5 rounded-2xl bg-tile" />
        </div>
        <span class="h-9 w-72 rounded-lg bg-tile" aria-hidden="true" />
        <div class="grid grid-cols-[repeat(auto-fill,minmax(15rem,1fr))] gap-4" aria-hidden="true">
          <span v-for="index in 3" :key="index" class="h-56 rounded-2xl bg-tile" />
        </div>
      </div>

      <div v-else-if="state.status === 'failed'" class="flex flex-col items-center gap-5 pb-16 pt-41.25">
        <LayoutEmptyState icon="folder" :title="VAULT_LOAD_FAILED_TITLE" :message="state.loadError ?? VAULT_ERROR_GENERIC" />
        <button
          type="button"
          class="min-h-10 rounded-field border border-brand px-4 text-base font-medium text-brand hover:bg-tint focus-visible:outline-2 focus-visible:outline-brand"
          @click="vault.retry()"
        >
          {{ VAULT_RETRY }}
        </button>
      </div>

      <template v-else>
        <!-- The folders and the filter bar stay in place (under the title); the evidence scrolls away under them. -->
        <div
          :class="hasScrolled ? '[@media(min-height:44rem)]:border-card-line' : ''"
          class="-mx-4 flex flex-col border-b border-transparent bg-white px-4 pb-3.5 pt-25.25 transition-colors sm:-mx-2 sm:px-2 [@media(min-height:44rem)]:sticky [@media(min-height:44rem)]:top-0 [@media(min-height:44rem)]:z-[5]"
        >
        <!-- Folders: standard ones first, then your own. Drag the row (or scroll it) to see the rest. -->
        <section v-if="filter.shelf.kind === 'all'" class="flex flex-col gap-1" :aria-label="VAULT_FOLDERS">
          <ul
            ref="shelfRow"
            :class="drag?.isDragging ? 'cursor-grabbing select-none' : shelfFade.left || shelfFade.right ? 'cursor-grab' : ''"
            :style="shelfMask"
            class="-mx-2 -my-2 flex gap-3 overflow-x-auto px-2 py-2 [scrollbar-width:none] [&::-webkit-scrollbar]:hidden"
            @scroll.passive="updateShelfFade"
            @pointerdown="startDrag"
            @pointermove="moveDrag"
            @pointerup="endDrag"
            @pointercancel="endDrag"
            @click.capture="stopClickAfterDrag"
            @dragstart.prevent
          >
            <!-- At least 9.5rem wide (six fit on a laptop); with room to spare the folders share the whole row, so it ends where the cards end. -->
            <li v-for="entry in vault.shelves.value" :key="entry.folder.id" class="min-w-0 max-w-64 flex-[1_0_9.5rem]">
              <VaultFolderTile
                :title="entry.folder.name"
                :icon="entry.iconSrc"
                :color="entry.hex"
                :surface="entry.surface"
                :count="entry.count"
                @open="openFolder(entry.folder.id)"
              >
                <template #actions>
                  <AylaRowMenu
                    floats
                    :items="FOLDER_ACTIONS"
                    :label="VAULT_FOLDER_ACTIONS(entry.folder.name)"
                    @select="handleFolderAction(entry.folder, $event)"
                  />
                </template>
              </VaultFolderTile>
            </li>
          </ul>
        </section>

        <!-- An open folder: back to the whole vault, its name and how much is in it. -->
        <div v-else class="flex flex-col items-start gap-3">
          <button
            type="button"
            class="-ml-2 flex h-8 items-center gap-2 rounded-lg px-2 text-sm font-medium text-subtle hover:bg-surface hover:text-heading focus-visible:outline-2 focus-visible:outline-brand"
            @click="closeShelf"
          >
            <VaultIcon src="/images/vault/icons/ArrowLeft.svg" class="size-4" />
            {{ VAULT_BACK_TO_VAULT }}
          </button>
          <div class="flex w-full items-center gap-3">
            <VaultFolderBadge v-if="openEntry" :icon="openEntry.iconSrc" :color="openEntry.hex" size="large" />
            <div class="flex min-w-0 flex-1 flex-col">
              <h3 class="truncate font-heading text-xl font-semibold text-heading">{{ shelfFolder?.name }}</h3>
              <p class="text-xs font-medium text-ink-soft">{{ itemCount(vault.count(filter.shelf)) }}</p>
            </div>
            <AylaRowMenu
              v-if="openEntry"
              floats
              :items="FOLDER_ACTIONS"
              :label="VAULT_FOLDER_ACTIONS(openEntry.folder.name)"
              @select="handleFolderAction(openEntry.folder, $event)"
            />
          </div>
        </div>

        <VaultToolbar
          v-model:filter="filter"
          v-model:is-grid="isGrid"
          v-model:is-searching="isSearching"
          class="mt-6"
          @new-folder="folderSheet = 'new'"
          @add="add"
        />

        <div v-if="isSearching" class="mt-3 flex h-9.5 items-center gap-3 rounded-field border border-field-line bg-white px-3 focus-within:border-brand">
          <VaultIcon src="/images/vault/toolbar-search.svg" class="size-5 text-subtle" />
          <label :for="searchId" class="sr-only">{{ VAULT_SEARCH }}</label>
          <input
            :id="searchId"
            ref="search"
            v-model="filter.searchText"
            type="search"
            :placeholder="VAULT_SEARCH_PLACEHOLDER"
            class="min-w-0 flex-1 bg-transparent text-sm font-medium text-heading placeholder:text-subtle/50 focus:outline-none"
            @keydown.esc="isSearching = false"
          />
        </div>

        </div>

        <p class="sr-only" aria-live="polite">{{ itemCount(visibleItems.length) }}</p>

        <!-- Nothing to show: what to do next depends on why, as on iOS. -->
        <div v-if="emptyKind" class="flex flex-col items-center gap-5 py-12">
          <template v-if="emptyKind === 'vault'">
            <LayoutEmptyState icon="folder" :title="VAULT_EMPTY_TITLE" :message="VAULT_EMPTY_MESSAGE" />
            <button type="button" :class="primaryButton" @click="add">{{ VAULT_ADD_ITEM }}</button>
          </template>
          <template v-else-if="emptyKind === 'noResults'">
            <LayoutEmptyState icon="search" :title="VAULT_NO_RESULTS_TITLE" :message="VAULT_NO_RESULTS_MESSAGE" />
            <button type="button" :class="primaryButton" @click="clearFilters">{{ VAULT_FILTER_CLEAR }}</button>
          </template>
          <template v-else-if="shelfFolder">
            <LayoutEmptyState icon="folder" :title="VAULT_FOLDER_EMPTY_TITLE(shelfFolder.name)" :message="VAULT_EMPTY_FOLDER_MESSAGE" />
            <button type="button" :class="primaryButton" @click="add">{{ VAULT_ADD_ITEM }}</button>
          </template>
        </div>

        <ul
          v-else
          :class="isGrid ? 'grid grid-cols-[repeat(auto-fill,minmax(15rem,1fr))] gap-4' : 'flex flex-col gap-2.5'"
          class="mt-1.5"
        >
          <li v-for="item in shownItems" :key="item.id" class="flex">
            <VaultItemCard
              :item="item"
              :is-grid="isGrid"
              @open="openedId = item.id"
              @action="handleItemAction(item, $event)"
            />
          </li>
        </ul>

        <button
          v-if="shownItems.length < visibleItems.length"
          type="button"
          class="mx-auto mt-5 flex h-9 items-center gap-2 rounded-lg bg-brand pl-2.25 pr-3 text-sm font-medium text-surface hover:bg-ink focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-brand"
          @click="shownCount += PAGE_SIZE"
        >
          {{ VAULT_SHOW_MORE }}
          <img src="/images/vault/chevron-down.svg" alt="" width="16" height="16" />
        </button>
      </template>
    </div>

    <VaultItemDialog :item-id="openedId" @close="openedId = null" @edit="editFromDetails" @request-confirmation="confirmFromDetails" />
    <VaultItemEditDialog :item-id="editedId" @close="editedId = null" />
    <VaultRequestDialog :item-id="confirmedId" @close="confirmedId = null" />
    <VaultFolderDialog :folder="folderSheet" @close="folderSheet = null" @created="folderCreated" />
    <LayoutConfirmSheet
      ref="confirmDeleteFolder"
      :title="VAULT_FOLDER_DELETE_TITLE"
      :message="VAULT_FOLDER_DELETE_MESSAGE"
      :confirm-label="VAULT_FOLDER_DELETE"
      @confirm="deleteFolder"
    />
    <LayoutConfirmSheet
      ref="confirmDeleteItem"
      :title="VAULT_DELETE_TITLE"
      :message="VAULT_DELETE_MESSAGE"
      :confirm-label="VAULT_DELETE"
      @confirm="deleteItem"
    />

    <!-- Moving or deleting did not work. -->
    <p
      v-if="state.problem"
      role="alert"
      class="fixed bottom-6 left-1/2 z-40 flex -translate-x-1/2 items-center gap-3 rounded-xl bg-ink px-4 py-3 text-sm text-white shadow-lg"
    >
      {{ state.problem }}
      <button type="button" class="font-semibold underline" @click="vault.state.value.problem = null">{{ VAULT_OK }}</button>
    </p>
  </div>
</template>

