<script setup lang="ts">
import type { RowMenuItem } from '~/types/ayla';
import type { VaultFilter, VaultFolder, VaultItem, VaultItemCategory, VaultShelf, VaultShelfEntry } from '~/types/vault';

// Your vault (iOS VaultScreen, Figma 1209:55066 and 1209:53998): a row of folders on top that you can drag sideways,
// then everything in it as tiles or a list. A folder opens on its own (?map= in the address, so the back button closes it
// again). Every folder, standard or your own, can be changed or removed. It reads and writes your own Supabase rows;
// adding goes through "Kluis aanvullen".
const vault = useVault();
const route = useRoute();
const router = useRouter();
const vaultAdd = useVaultAdd();

const PAGE_SIZE = 9;
// Moved further than this, a press on the folder row is a drag and not a click on a folder.
const DRAG_DISTANCE = 6;
const primaryButton =
  'min-h-10 min-w-50 rounded-lg bg-brand px-4 text-sm font-medium text-white hover:bg-ink focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-brand';
const textButton =
  'flex h-8 items-center gap-1 rounded-lg px-2 text-sm font-medium text-brand hover:bg-tint focus-visible:outline-2 focus-visible:outline-brand';
const GRID_KEY = 'pave-vault-grid';

const filter = ref<VaultFilter>(createFilter());
const isGrid = ref(true);
const isSearching = ref(false);
const shelfRowRef = useTemplateRef<HTMLUListElement>('shelfRow');
const drag = ref<{ x: number; scrollLeft: number; isDragging: boolean } | null>(null);
const shownCount = ref(PAGE_SIZE);
const openedId = ref<string | null>(null);
const editedId = ref<string | null>(null);
const folderSheet = ref<VaultShelfEntry | 'new' | null>(null);
const deletedFolder = ref<VaultShelfEntry | null>(null);
const deletedItem = ref<VaultItem | null>(null);
const deleteFolderRef = useTemplateRef<{ open: () => void }>('confirmDeleteFolder');
const deleteItemRef = useTemplateRef<{ open: () => void }>('confirmDeleteItem');
const searchRef = useTemplateRef<HTMLInputElement>('search');
const searchId = useId();

const state = computed(() => vault.state.value);
const visibleItems = computed(() => applyFilter(state.value.items, filter.value));
const shownItems = computed(() => visibleItems.value.slice(0, shownCount.value));
const hasHiddenFolders = computed(() => Object.values(state.value.categoryFolders).some((folder) => folder?.isHidden));

const FOLDER_ACTIONS: RowMenuItem[] = [
  { id: 'edit', label: VAULT_FOLDER_EDIT },
  { id: 'delete', label: VAULT_FOLDER_DELETE, isDanger: true },
];

const shelfCategory = computed<VaultItemCategory | undefined>(() =>
  filter.value.shelf.kind === 'category' ? filter.value.shelf.category : undefined,
);
const shelfFolder = computed(() => (filter.value.shelf.kind === 'folder' ? vault.folder(filter.value.shelf.id) : null));
/** The open folder as it looks in the row; a standard folder you removed is still shown under its own name. */
const openEntry = computed(() => vault.shelves.value.find((entry) => isSameShelf(entry.shelf, filter.value.shelf)) ?? null);
const openTitle = computed(() => {
  if (openEntry.value) return openEntry.value.title;
  return shelfCategory.value ? VAULT_CATEGORY_PLURALS[shelfCategory.value] : (shelfFolder.value?.name ?? '');
});

type EmptyKind = 'vault' | 'noResults' | 'folder' | 'category';
const emptyKind = computed<EmptyKind | null>(() => {
  if (visibleItems.value.length) return null;
  if (!state.value.items.length) return 'vault';
  if (filter.value.searchText.trim() || narrowsDown(filter.value)) return 'noResults';
  if (shelfFolder.value) return 'folder';
  return 'category';
});

/** The folder in the address: a category ("certificates") or the id of a folder you made. */
function shelfFromRoute(): VaultShelf {
  const map = typeof route.query.map === 'string' ? route.query.map : '';
  if ((VAULT_CATEGORIES as string[]).includes(map)) {
    const entry = vault.shelves.value.find((shelf) => shelf.shelf.kind === 'category' && shelf.shelf.category === map);
    return entry?.shelf ?? { kind: 'category', category: map as VaultItemCategory };
  }
  if (map && vault.folder(map)) return { kind: 'folder', id: map };
  return { kind: 'all' };
}

function openShelf(shelf: VaultShelf) {
  const map = shelf.kind === 'category' ? shelf.category : shelf.kind === 'folder' ? shelf.id : undefined;
  router.push({ query: { ...route.query, map } });
}

function closeShelf() {
  const { map: _, ...query } = route.query;
  router.push({ query });
}

function add() {
  vaultAdd.open({ category: shelfCategory.value, folderId: shelfFolder.value?.id ?? null });
}

function clearFilters() {
  filter.value = createFilter();
}

function handleFolderAction(entry: VaultShelfEntry, action: string) {
  if (action === 'edit') {
    folderSheet.value = entry;
    return;
  }
  deletedFolder.value = entry;
  deleteFolderRef.value?.open();
}

/** Your own folder is deleted; a standard folder only leaves the row. The items stay in the vault either way. */
async function deleteFolder() {
  const entry = deletedFolder.value;
  if (!entry) return;
  if (isSameShelf(filter.value.shelf, entry.shelf)) closeShelf();
  if (entry.shelf.kind === 'folder') {
    await vault.deleteFolder(entry.shelf.id);
    return;
  }
  const category = entry.shelf.category;
  await vault.updateCategoryFolder(category, { ...state.value.categoryFolders[category], isHidden: true });
}

function folderCreated(folder: VaultFolder) {
  folderSheet.value = null;
  openShelf({ kind: 'folder', id: folder.id });
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

function handleItemAction(item: VaultItem, action: 'edit' | 'delete') {
  if (action === 'edit') editedId.value = item.id;
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


// The address says which folder is open; the folders you made are only known once the vault has loaded.
watch(
  () => [route.query.map, state.value.status, vault.shelves.value],
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
});
</script>

<template>
  <div class="flex min-h-0 min-w-0 flex-1 flex-col overflow-y-auto overflow-x-hidden px-4 pb-40 sm:px-13.25">
    <div class="mx-auto flex w-full max-w-267 flex-col">
      <h2 class="sr-only">{{ VAULT_TITLE }}</h2>

      <!-- Loading: grey shapes where the folders and cards will appear. -->
      <div v-if="state.status === 'loading'" class="flex animate-pulse flex-col gap-6 motion-reduce:animate-none" role="status">
        <span class="sr-only">{{ VAULT_LOADING }}</span>
        <div class="grid grid-cols-2 gap-3 sm:grid-cols-4" aria-hidden="true">
          <span v-for="index in 4" :key="index" class="h-27.5 rounded-2xl bg-tile" />
        </div>
        <span class="h-9 w-72 rounded-lg bg-tile" aria-hidden="true" />
        <div class="grid grid-cols-[repeat(auto-fill,minmax(15rem,1fr))] gap-4" aria-hidden="true">
          <span v-for="index in 3" :key="index" class="h-56 rounded-2xl bg-tile" />
        </div>
      </div>

      <div v-else-if="state.status === 'failed'" class="flex flex-col items-center gap-5 py-16">
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
        <!-- Folders: standard ones first, then your own. Drag the row (or scroll it) to see the rest. -->
        <section v-if="filter.shelf.kind === 'all'" class="flex flex-col gap-1" :aria-label="VAULT_FOLDERS">
          <ul
            ref="shelfRow"
            :class="drag?.isDragging ? 'cursor-grabbing select-none' : 'cursor-grab'"
            class="-mx-4 -my-2 flex gap-3 overflow-x-auto px-4 py-2 [scrollbar-width:none] sm:-mx-2 sm:px-2 [&::-webkit-scrollbar]:hidden"
            @pointerdown="startDrag"
            @pointermove="moveDrag"
            @pointerup="endDrag"
            @pointercancel="endDrag"
            @click.capture="stopClickAfterDrag"
            @dragstart.prevent
          >
            <li v-for="entry in vault.shelves.value" :key="entry.key" class="w-44 shrink-0">
              <VaultFolderTile
                :title="entry.title"
                :icon="entry.iconSrc"
                :color="entry.hex"
                :surface="entry.surface"
                :count="entry.count"
                @open="openShelf(entry.shelf)"
              >
                <template #actions>
                  <AylaRowMenu
                    floats
                    :items="FOLDER_ACTIONS"
                    :label="VAULT_FOLDER_ACTIONS(entry.title)"
                    @select="handleFolderAction(entry, $event)"
                  />
                </template>
              </VaultFolderTile>
            </li>
          </ul>
          <button v-if="hasHiddenFolders" type="button" :class="textButton" class="self-end" @click="vault.restoreCategoryFolders()">
            {{ VAULT_RESTORE_FOLDERS }}
          </button>
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
              <h3 class="truncate font-heading text-xl font-semibold text-heading">{{ openTitle }}</h3>
              <p class="text-xs font-medium text-ink-soft">{{ itemCount(vault.count(filter.shelf)) }}</p>
            </div>
            <AylaRowMenu
              v-if="openEntry"
              :items="FOLDER_ACTIONS"
              :label="VAULT_FOLDER_ACTIONS(openEntry.title)"
              @select="handleFolderAction(openEntry, $event)"
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
          <LayoutEmptyState
            v-else-if="emptyKind === 'folder' && shelfFolder"
            icon="folder"
            :title="VAULT_FOLDER_EMPTY_TITLE(openTitle)"
            :message="VAULT_EMPTY_FOLDER_MESSAGE"
          />
          <template v-else-if="shelfCategory">
            <LayoutEmptyState
              icon="folder"
              :title="VAULT_EMPTY_CATEGORY_TITLE(openTitle)"
              :message="VAULT_EMPTY_MESSAGE"
            />
            <button type="button" :class="primaryButton" @click="add">
              {{ VAULT_ADD_CATEGORY(VAULT_CATEGORY_TITLES[shelfCategory]) }}
            </button>
          </template>
        </div>

        <ul
          v-else
          :class="isGrid ? 'grid grid-cols-[repeat(auto-fill,minmax(15rem,1fr))] gap-4' : 'flex flex-col gap-2.5'"
          class="mt-5"
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

    <VaultItemDialog :item-id="openedId" @close="openedId = null" @edit="editFromDetails" />
    <VaultItemEditDialog :item-id="editedId" @close="editedId = null" />
    <VaultFolderDialog :folder="folderSheet" @close="folderSheet = null" @created="folderCreated" />
    <LayoutConfirmSheet
      ref="confirmDeleteFolder"
      :title="VAULT_FOLDER_DELETE_TITLE"
      :message="deletedFolder?.isStandard ? VAULT_STANDARD_FOLDER_DELETE_MESSAGE : VAULT_FOLDER_DELETE_MESSAGE"
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

