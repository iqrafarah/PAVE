<script setup lang="ts">
import type { VaultFilter, VaultOrder, VaultOrigin, VaultStatus } from '~/types/vault';

// The bar above the vault items (Figma 1209:55066): Alle, Status, Bron and Datum on the left; grid or list, search and
// "Toevoegen" on the right. "Toevoegen" opens "Item toevoegen" and "Map aanmaken", like the plus menu on iOS.
const filter = defineModel<VaultFilter>('filter', { required: true });
const isGrid = defineModel<boolean>('isGrid', { required: true });
const isSearching = defineModel<boolean>('isSearching', { required: true });

const emit = defineEmits<{
  newFolder: [];
  add: [];
}>();

const ADD_OPTIONS = [
  { id: 'item', label: VAULT_ADD_ITEM, icon: '/images/vault/icons/DocumentPlusSolid.svg' },
  { id: 'folder', label: VAULT_FOLDER_CREATE, icon: '/images/vault/icons/FolderPlusSolid.svg' },
];

function chooseAdd(id: string) {
  if (id === 'folder') emit('newFolder');
  else emit('add');
}

const statusOptions = computed(() =>
  VAULT_STATUSES.map((status) => ({ id: status, label: VAULT_STATUS_TITLES[status], isChecked: filter.value.status === status })),
);
const originOptions = computed(() =>
  VAULT_ORIGINS.map((origin) => ({ id: origin, label: VAULT_ORIGIN_TITLES[origin], isChecked: filter.value.origin === origin })),
);
const orderOptions = computed(() =>
  (['newest', 'oldest'] as VaultOrder[]).map((order) => ({ id: order, label: VAULT_ORDER_TITLES[order], isChecked: filter.value.order === order })),
);

function selectStatus(id: string) {
  filter.value.status = filter.value.status === id ? null : (id as VaultStatus);
}

function selectOrigin(id: string) {
  filter.value.origin = filter.value.origin === id ? null : (id as VaultOrigin);
}

/** "Alle" clears Status and Bron, not the folder you are in or the order (iOS VaultFilter.narrowsDown). */
function clearFilters() {
  filter.value.status = null;
  filter.value.origin = null;
}

// Figma: "Alle" is a chip, Status, Bron and Datum are plain words until one of them filters.
const tab = 'flex h-9 items-center rounded-lg text-[0.9375rem] font-medium text-heading focus-visible:outline-2 focus-visible:outline-brand';
const allOn = `${tab} bg-tint px-3.25`;
const allOff = `${tab} px-3.25 hover:bg-surface`;
const tabOn = `${tab} bg-tint px-2`;
const tabOff = `${tab} px-2 hover:bg-surface`;

const iconButton =
  'flex size-9 shrink-0 items-center justify-center rounded-field border focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-brand';
const offButton = 'border-toolbar-line bg-surface text-heading hover:bg-tint';
const onButton = 'border-brand bg-brand text-white';
</script>

<template>
  <div class="flex flex-wrap items-center justify-between gap-x-6 gap-y-3">
    <div class="flex flex-wrap items-center gap-x-1.5 gap-y-1">
      <button type="button" :aria-pressed="!narrowsDown(filter)" :class="narrowsDown(filter) ? allOff : allOn" @click="clearFilters">
        {{ VAULT_FILTER_ALL }}
      </button>
      <VaultMenu
        class="ml-1.5"
        :label="VAULT_FILTER_STATUS"
        :options="statusOptions"
        :toggle-class="filter.status ? tabOn : tabOff"
        :summary="filter.status ? VAULT_STATUS_TITLES[filter.status] : undefined"
        @select="selectStatus"
      />
      <VaultMenu
        :label="VAULT_FILTER_SOURCE"
        :options="originOptions"
        :toggle-class="filter.origin ? tabOn : tabOff"
        :summary="filter.origin ? VAULT_ORIGIN_TITLES[filter.origin] : undefined"
        @select="selectOrigin"
      />
      <VaultMenu
        :label="VAULT_FILTER_DATE"
        :options="orderOptions"
        :toggle-class="tabOff"
        :summary="VAULT_ORDER_TITLES[filter.order]"
        @select="filter.order = $event as VaultOrder"
      />
    </div>

    <div class="flex flex-wrap items-center gap-2.5">
      <div class="flex gap-2.5" role="group" :aria-label="VAULT_VIEW">
        <button
          type="button"
          :aria-pressed="isGrid"
          :aria-label="VAULT_SHOW_GRID"
          :title="VAULT_SHOW_GRID"
          :class="[iconButton, isGrid ? onButton : offButton]"
          @click="isGrid = true"
        >
          <VaultIcon src="/images/vault/view-grid.svg" class="size-5" />
        </button>
        <button
          type="button"
          :aria-pressed="!isGrid"
          :aria-label="VAULT_SHOW_LIST"
          :title="VAULT_SHOW_LIST"
          :class="[iconButton, isGrid ? offButton : onButton]"
          @click="isGrid = false"
        >
          <VaultIcon src="/images/vault/view-list.svg" class="h-3.5 w-4.5" />
        </button>
      </div>
      <button
        type="button"
        :aria-pressed="isSearching"
        :aria-label="isSearching ? VAULT_SEARCH_CLOSE : VAULT_SEARCH"
        :title="isSearching ? VAULT_SEARCH_CLOSE : VAULT_SEARCH"
        :class="[iconButton, isSearching ? onButton : offButton]"
        @click="isSearching = !isSearching"
      >
        <VaultIcon src="/images/vault/toolbar-search.svg" class="size-5" />
      </button>
      <VaultMenu
        :label="VAULT_ADD_BUTTON"
        :options="ADD_OPTIONS"
        align="right"
        toggle-class="flex h-9 items-center gap-2 rounded-lg bg-brand pl-2.75 pr-3.25 text-[0.9375rem] font-medium text-surface hover:bg-ink focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-brand"
        @select="chooseAdd"
      >
        <template #label>
          <VaultIcon src="/images/vault/plus.svg" class="h-3 w-3.25" />
          {{ VAULT_ADD_BUTTON }}
        </template>
      </VaultMenu>
    </div>
  </div>
</template>
