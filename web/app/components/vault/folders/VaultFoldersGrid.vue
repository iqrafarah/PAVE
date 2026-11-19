<script setup lang="ts">
import type { RowMenuItem } from '~/types/ayla';
import type { VaultFolder, VaultShelfEntry } from '~/types/vault';

// "Alle mappen" (a screen of its own, like an open folder): every folder in a grid, for when the row on top shows only
// the first few. With many folders you can search by name; the folders keep the order of the row (pinned ones first).
const props = defineProps<{
  entries: VaultShelfEntry[];
  actions: (folder: VaultFolder) => RowMenuItem[];
}>();

const emit = defineEmits<{
  open: [folderId: string];
  action: [folder: VaultFolder, action: string];
}>();

// Searching only helps from this many folders on.
const SEARCH_FROM = 9;
const vault = useVault();
const query = ref('');
// While a folder is dragged the others make room at once; the order is saved when it is let go.
const dragged = ref<string | null>(null);
const liveOrder = ref<string[] | null>(null);

// Accents and capitals do not matter ("Ontwikkeling" is found with "ontwikkeling", "Café" with "cafe").
const fold = (text: string) => text.normalize('NFD').replace(/\p{M}/gu, '').toLocaleLowerCase();
const isSearching = computed(() => query.value.trim() !== '');
const ordered = computed(() => {
  const order = liveOrder.value;
  if (!order) return props.entries;
  return order.flatMap((id) => props.entries.filter((entry) => entry.folder.id === id));
});
const shown = computed(() => {
  const needle = fold(query.value.trim());
  return needle ? ordered.value.filter((entry) => fold(entry.folder.name).includes(needle)) : ordered.value;
});

function moveWithin(order: string[], id: string, targetId: string) {
  const from = order.indexOf(id);
  const to = order.indexOf(targetId);
  if (from === -1 || to === -1 || from === to) return order;
  const next = [...order];
  next.splice(from, 1);
  next.splice(to, 0, id);
  return next;
}

function startDragging(id: string, event: DragEvent) {
  dragged.value = id;
  liveOrder.value = props.entries.map((entry) => entry.folder.id);
  if (event.dataTransfer) {
    event.dataTransfer.effectAllowed = 'move';
    event.dataTransfer.setData('text/plain', id);
  }
}

function dragOver(targetId: string, event: DragEvent) {
  if (!dragged.value || !liveOrder.value) return;
  event.preventDefault();
  liveOrder.value = moveWithin(liveOrder.value, dragged.value, targetId);
}

async function endDragging() {
  const order = liveOrder.value;
  dragged.value = null;
  if (order) await vault.setFolderOrder(order);
  liveOrder.value = null;
}

/** The keyboard way to move a folder: Alt with the arrow keys. */
async function nudge(entry: VaultShelfEntry, step: -1 | 1) {
  const order = props.entries.map((candidate) => candidate.folder.id);
  const target = order[order.indexOf(entry.folder.id) + step];
  if (!target) return;
  await vault.setFolderOrder(moveWithin(order, entry.folder.id, target));
  await nextTick();
  (document.getElementById(`vault-all-folder-${entry.folder.id}`)?.querySelector('button') as HTMLElement | null)?.focus();
}
</script>

<template>
  <div class="flex flex-col gap-5 pt-1.5">
      <LayoutSearchInput v-if="entries.length >= SEARCH_FROM" v-model="query" :label="VAULT_FOLDERS_SEARCH" :placeholder="VAULT_FOLDERS_SEARCH" />

      <ul v-if="shown.length" class="grid grid-cols-[repeat(auto-fill,minmax(9.5rem,1fr))] gap-3">
        <template v-for="entry in shown" :key="entry.folder.id">
        <li
          :id="`vault-all-folder-${entry.folder.id}`"
          :draggable="!isSearching"
          :class="dragged === entry.folder.id ? 'opacity-40' : ''"
          class="min-w-0"
          @dragstart="startDragging(entry.folder.id, $event)"
          @dragover="dragOver(entry.folder.id, $event)"
          @dragend="endDragging"
          @keydown.alt.left.prevent="nudge(entry, -1)"
          @keydown.alt.right.prevent="nudge(entry, 1)"
          @keydown.alt.up.prevent="nudge(entry, -1)"
          @keydown.alt.down.prevent="nudge(entry, 1)"
        >
          <VaultFolderTile
            :title="entry.folder.name"
            :icon="entry.iconSrc"
            :color="entry.hex"
            :surface="entry.surface"
            :icon-color="entry.iconColor"
            :is-pinned="Boolean(entry.folder.pinnedAt)"
            :count="entry.count"
            @open="emit('open', entry.folder.id)"
          >
            <template #actions>
              <AylaRowMenu
                floats
                :items="actions(entry.folder)"
                :label="VAULT_FOLDER_ACTIONS(entry.folder.name)"
                @select="emit('action', entry.folder, $event)"
              />
            </template>
          </VaultFolderTile>
        </li>
        </template>
      </ul>
      <p v-else role="status" class="py-6 text-center text-sm text-subtle">{{ VAULT_FOLDERS_NONE_FOUND(query.trim()) }}</p>
  </div>
</template>
