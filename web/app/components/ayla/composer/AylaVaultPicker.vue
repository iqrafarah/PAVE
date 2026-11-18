<script setup lang="ts">
import type { VaultItem } from '~/types/vault';

// "Item uit je kluis" from the plus button (iOS AylaVaultSelectionSheet, Figma FEDDIES 1348:6): your folders on top, your
// evidence under them as in the vault, and the number chosen with "Verder" at the bottom. A folder chooses everything in
// it. What is chosen is what the conversation is about from here on; items Ayla may not use yet ask first, once for all
// of them.
const emit = defineEmits<{
  pick: [items: VaultItem[]];
}>();

const vault = useVault();
const dialogRef = useTemplateRef<HTMLDialogElement>('dialog');
const titleId = useId();
const selected = ref<Set<string>>(new Set());
const asksPermission = ref<VaultItem[] | null>(null);
const isSaving = ref(false);

const items = computed(() => applyFilter(vault.state.value.items, createFilter()));
const chosen = computed(() => items.value.filter((item) => selected.value.has(item.id)));
const folders = computed(() => vault.shelves.value);

function open() {
  selected.value = new Set();
  asksPermission.value = null;
  dialogRef.value?.showModal();
  if (vault.state.value.status !== 'ready') vault.load();
}

function close() {
  dialogRef.value?.close();
}

defineExpose({ open });

function toggle(id: string) {
  const next = new Set(selected.value);
  if (next.has(id)) next.delete(id);
  else next.add(id);
  selected.value = next;
}

/** A folder chooses everything in it, or takes everything in it away again when it was all chosen already. */
function toggleGroup(group: VaultItem[]) {
  const ids = group.map((item) => item.id);
  if (!ids.length) return;
  const next = new Set(selected.value);
  const isOn = ids.every((id) => next.has(id));
  for (const id of ids) {
    if (isOn) next.delete(id);
    else next.add(id);
  }
  selected.value = next;
}

const isGroupOn = (group: VaultItem[]) => group.length > 0 && group.every((item) => selected.value.has(item.id));
const folderItems = (folderId: string) => items.value.filter((item) => item.folderIds.includes(folderId));

function continueWithChosen() {
  if (!chosen.value.length) return;
  const notAllowed = chosen.value.filter((item) => !item.aylaAllowedAt);
  if (notAllowed.length) asksPermission.value = notAllowed;
  else finish(chosen.value);
}

async function allowAll() {
  const notAllowed = asksPermission.value ?? [];
  const everything = chosen.value;
  isSaving.value = true;
  for (const item of notAllowed) await vault.setAylaAllowed(item.id, true).catch(() => undefined);
  await vault.load();
  isSaving.value = false;
  finish(everything);
}

function finish(picked: VaultItem[]) {
  emit('pick', picked);
  close();
}

function handleBackdropClick(event: MouseEvent) {
  if (event.target === dialogRef.value) close();
}
</script>

<template>
  <dialog
    ref="dialog"
    :aria-labelledby="titleId"
    class="m-auto max-h-[calc(100dvh-2rem)] w-[calc(100%-2rem)] max-w-154 overflow-hidden rounded-modal bg-white p-0 text-heading shadow-modal backdrop:bg-backdrop"
    @click="handleBackdropClick"
  >
    <div class="flex max-h-[calc(100dvh-2rem)] flex-col">
      <div class="flex items-start justify-between gap-4 px-9 pt-8 max-sm:px-5">
        <div class="flex flex-col gap-1">
          <h2 :id="titleId" class="font-heading text-2xl font-semibold text-heading">{{ AYLA_PICK_ITEM_TITLE }}</h2>
          <p class="text-xs font-medium text-subtle">{{ AYLA_PICK_ITEM_HINT }}</p>
        </div>
        <button
          type="button"
          :aria-label="AYLA_PICK_CLOSE"
          :title="AYLA_PICK_CLOSE"
          class="-mr-2 flex size-9 shrink-0 items-center justify-center rounded-field hover:bg-surface focus-visible:outline-2 focus-visible:outline-brand"
          @click="close"
        >
          <VaultIcon src="/images/vault/close.svg" :width="13.6909" :height="13.6909" class="text-brand" />
        </button>
      </div>

      <div v-if="vault.state.value.status === 'ready' && !items.length" class="px-9 py-12 max-sm:px-5">
        <LayoutEmptyState icon="folder" :title="AYLA_VAULT_EMPTY_NOTE" :message="VAULT_EMPTY_MESSAGE" />
      </div>

      <div v-else class="min-h-0 flex-1 overflow-y-auto px-9 pb-4 pt-6 max-sm:px-5">
        <!-- "Alle items" and your folders; one tile chooses everything in it. -->
        <ul class="-mx-2 -my-2 flex gap-3 overflow-x-auto px-2 py-2 [scrollbar-width:none] [&::-webkit-scrollbar]:hidden">
          <li class="relative w-38 shrink-0">
            <VaultFolderTile
              :title="AYLA_ALL_ITEMS"
              icon="/images/vault/icons/FolderOutline.svg"
              :count="items.length"
              :class="isGroupOn(items) ? 'rounded-2xl ring-2 ring-brand' : ''"
              :aria-pressed="isGroupOn(items)"
              @open="toggleGroup(items)"
            />
            <span v-if="isGroupOn(items)" class="pointer-events-none absolute right-2 top-2 flex size-5 items-center justify-center rounded-full bg-brand text-white" aria-hidden="true"><LayoutPaveIcon name="check" class="size-3" /></span>
          </li>
          <li v-for="entry in folders" :key="entry.folder.id" class="relative w-38 shrink-0">
            <VaultFolderTile
              :title="entry.folder.name"
              :icon="entry.iconSrc"
              :color="entry.hex"
              :surface="entry.surface"
              :count="folderItems(entry.folder.id).length"
              :class="isGroupOn(folderItems(entry.folder.id)) ? 'rounded-2xl ring-2 ring-brand' : ''"
              @open="toggleGroup(folderItems(entry.folder.id))"
            />
            <span v-if="isGroupOn(folderItems(entry.folder.id))" class="pointer-events-none absolute right-2 top-2 flex size-5 items-center justify-center rounded-full bg-brand text-white" aria-hidden="true"><LayoutPaveIcon name="check" class="size-3" /></span>
          </li>
        </ul>

        <ul class="mt-5 flex flex-col gap-3">
          <li v-for="item in items" :key="item.id" class="relative">
            <!-- The card is only to look at here; the whole tile is the choice. -->
            <div inert :class="selected.has(item.id) ? 'rounded-2xl ring-2 ring-brand' : ''">
              <VaultItemCard :item="item" :is-grid="false" />
            </div>
            <button
              type="button"
              role="checkbox"
              :aria-checked="selected.has(item.id)"
              :aria-label="item.title"
              class="absolute inset-0 rounded-2xl focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-brand"
              @click="toggle(item.id)"
            />
            <span v-if="selected.has(item.id)" class="pointer-events-none absolute right-3 top-3 flex size-5 items-center justify-center rounded-full bg-brand text-white" aria-hidden="true"><LayoutPaveIcon name="check" class="size-3" /></span>
          </li>
        </ul>
      </div>

      <div class="border-t border-card-line px-9 pb-8 pt-5 max-sm:px-5">
        <template v-if="asksPermission">
          <h3 class="text-sm font-semibold text-heading">{{ AYLA_PICK_NOT_ALLOWED_TITLE(asksPermission.length) }}</h3>
          <p class="mt-1 text-xs font-medium text-subtle">{{ AYLA_ASK_NOT_ALLOWED_MESSAGE }}</p>
          <div class="mt-4 flex flex-wrap justify-end gap-2.5">
            <button
              type="button"
              class="min-h-10 rounded-field bg-field-line px-4 text-base font-medium text-heading hover:bg-tile focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-brand"
              @click="asksPermission = null"
            >
              {{ AYLA_CANCEL }}
            </button>
            <button
              v-if="chosen.length > asksPermission.length"
              type="button"
              class="min-h-10 rounded-field bg-field-line px-4 text-base font-medium text-heading hover:bg-tile focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-brand"
              @click="finish(chosen.filter((item) => !asksPermission?.includes(item)))"
            >
              {{ AYLA_ASK_WITHOUT_THEM }}
            </button>
            <button
              type="button"
              :disabled="isSaving"
              class="min-h-10 rounded-field bg-brand px-4 text-base font-medium text-white hover:bg-ink focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-brand disabled:opacity-60"
              @click="allowAll"
            >
              {{ AYLA_ASK_ALLOW_ALL }}
            </button>
          </div>
        </template>
        <button
          v-else
          type="button"
          :disabled="!chosen.length"
          class="min-h-11 w-full rounded-lg bg-brand text-base font-medium text-white hover:bg-ink focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-brand disabled:cursor-not-allowed disabled:opacity-50"
          @click="continueWithChosen"
        >
          {{ AYLA_PICK_CONTINUE(chosen.length) }}
        </button>
      </div>
    </div>
  </dialog>
</template>
