<script setup lang="ts">
// "Mappen" in the form (iOS VaultEvidenceForm): a dropdown in which several folders can be ticked; it stays open while
// you tick them and shows what is chosen. The list is placed on the screen itself, under the field or above it when
// there is no room below, so the window around the form never cuts it off. When adding evidence of a kind without a
// folder (such as a stage without Stages), that folder is offered as "Stages (nieuwe map)" and is made when you save,
// unless you untick it.
const props = defineProps<{
  id: string;
  // A folder for the kind that does not exist yet; null when there is nothing to make.
  newFolderName?: string | null;
}>();

const folderIds = defineModel<string[]>('folderIds', { required: true });
const makesNewFolder = defineModel<boolean>('makesNewFolder', { default: false });

const emit = defineEmits<{
  // The user chose folders on purpose, so they no longer follow the kind of evidence.
  chosen: [];
}>();

const vault = useVault();
const isOpen = ref(false);
const rootRef = useTemplateRef<HTMLDivElement>('root');
const toggleRef = useTemplateRef<HTMLButtonElement>('toggle');
const listRef = useTemplateRef<HTMLDivElement>('list');
const listId = useId();
const floatingStyle = ref<Record<string, string>>({});

// Opened from a chat, the vault may not have been read yet; the folders come with it.
onMounted(() => {
  if (vault.state.value.status !== 'ready') vault.load();
});

const chosenNames = computed(() => {
  const names = vault.state.value.folders.filter((folder) => folderIds.value.includes(folder.id)).map((folder) => folder.name);
  if (props.newFolderName && makesNewFolder.value) names.push(props.newFolderName);
  return names;
});

function toggle(folderId: string) {
  folderIds.value = folderIds.value.includes(folderId)
    ? folderIds.value.filter((id) => id !== folderId)
    : [...folderIds.value, folderId];
  emit('chosen');
}

function toggleNewFolder() {
  makesNewFolder.value = !makesNewFolder.value;
  emit('chosen');
}

/** As wide as the field; below it when it fits, otherwise above it, and never taller than the room there is. */
function place() {
  const rect = toggleRef.value?.getBoundingClientRect();
  if (!rect) return;
  const rows = vault.shelves.value.length + (props.newFolderName ? 1 : 0);
  const wanted = Math.min(Math.max(rows, 1) * 40 + 14, 300);
  const below = window.innerHeight - rect.bottom - 12;
  const above = rect.top - 12;
  const base = { position: 'fixed', left: `${rect.left}px`, width: `${rect.width}px` };
  floatingStyle.value =
    wanted > below && above > below
      ? { ...base, bottom: `${window.innerHeight - rect.top + 4}px`, maxHeight: `${Math.min(above, 300)}px` }
      : { ...base, top: `${rect.bottom + 4}px`, maxHeight: `${Math.min(below, 300)}px` };
}

function getOptions() {
  return Array.from(listRef.value?.querySelectorAll<HTMLButtonElement>('[role="option"]') ?? []);
}

async function open() {
  place();
  isOpen.value = true;
  await nextTick();
  getOptions()[0]?.focus();
}

function close(isReturningFocus: boolean) {
  isOpen.value = false;
  if (isReturningFocus) toggleRef.value?.focus();
}

function moveFocus(step: number) {
  const options = getOptions();
  const index = options.findIndex((option) => option === document.activeElement);
  options[(index + step + options.length) % options.length]?.focus();
}

function handleKeydown(event: KeyboardEvent) {
  if (!isOpen.value) return;
  // Escape closes the list only, not the window around the form.
  if (event.key === 'Escape') close(true);
  else if (event.key === 'ArrowDown') moveFocus(1);
  else if (event.key === 'ArrowUp') moveFocus(-1);
  else return;
  event.preventDefault();
  event.stopPropagation();
}

function handleFocusOut(event: FocusEvent) {
  if (!rootRef.value?.contains(event.relatedTarget as Node | null)) isOpen.value = false;
}

function handlePointerDown(event: PointerEvent) {
  if (!rootRef.value?.contains(event.target as Node)) isOpen.value = false;
}

// The form scrolling moves the field: the list follows it, and closes once the field is out of sight.
function follow(event: Event) {
  if (listRef.value?.contains(event.target as Node)) return;
  const rect = toggleRef.value?.getBoundingClientRect();
  if (!rect || rect.bottom < 0 || rect.top > window.innerHeight) isOpen.value = false;
  else place();
}

function listen(isOn: boolean) {
  const change = isOn ? window.addEventListener : window.removeEventListener;
  change('scroll', follow, true);
  change('resize', follow);
  (isOn ? document.addEventListener : document.removeEventListener)('pointerdown', handlePointerDown as EventListener);
}

watch(isOpen, listen);
onBeforeUnmount(() => listen(false));

const row =
  'flex min-h-10 w-full cursor-pointer items-center gap-2.5 rounded-lg px-2.5 text-left text-sm font-medium text-heading hover:bg-surface focus-visible:bg-surface focus-visible:outline-2 focus-visible:outline-brand';
const box = (isOn: boolean) => (isOn ? 'border-brand bg-brand text-white' : 'border-field-line bg-white');
</script>

<template>
  <div ref="root" class="relative" @focusout="handleFocusOut" @keydown="handleKeydown">
    <button
      :id="props.id"
      ref="toggle"
      type="button"
      aria-haspopup="listbox"
      :aria-expanded="isOpen"
      :aria-controls="isOpen ? listId : undefined"
      :class="isOpen ? 'border-brand' : 'border-field-line'"
      class="flex min-h-9.75 w-full min-w-0 cursor-pointer items-center justify-between gap-2 rounded-field border bg-white py-1 pl-1.5 pr-3 text-left text-sm font-medium focus-visible:border-brand focus-visible:outline-none"
      @click="isOpen ? close(false) : open()"
    >
      <!-- What is chosen, each folder as its own chip. -->
      <span v-if="chosenNames.length" class="flex min-w-0 flex-1 flex-wrap gap-1">
        <span v-for="name in chosenNames" :key="name" class="max-w-full truncate rounded-md bg-tint px-2 py-1 text-xs font-semibold text-brand">
          {{ name }}
        </span>
      </span>
      <span v-else class="flex-1 pl-1.5 text-subtle/70">{{ VAULT_NO_FOLDER }}</span>
      <LayoutPaveIcon name="chevronDown" :class="isOpen ? 'rotate-180' : ''" class="size-3.5 shrink-0 text-subtle transition-transform" />
    </button>
    <div
      v-if="isOpen"
      :id="listId"
      ref="list"
      role="listbox"
      aria-multiselectable="true"
      :aria-label="VAULT_FIELD_FOLDERS"
      :style="floatingStyle"
      class="z-50 overflow-y-auto rounded-xl border border-card-line bg-white p-1.5 shadow-modal"
    >
      <button v-if="newFolderName" type="button" role="option" :aria-selected="makesNewFolder" :class="row" @click="toggleNewFolder">
        <span :class="box(makesNewFolder)" class="flex size-4.5 shrink-0 items-center justify-center rounded border" aria-hidden="true">
          <LayoutPaveIcon v-if="makesNewFolder" name="check" class="size-3" />
        </span>
        <VaultFolderBadge icon="/images/vault/icons/FolderPlusSolid.svg" color="var(--color-brand)" />
        <span class="min-w-0 flex-1 truncate">{{ VAULT_NEW_KIND_FOLDER(newFolderName) }}</span>
      </button>
      <button
        v-for="entry in vault.shelves.value"
        :key="entry.folder.id"
        type="button"
        role="option"
        :aria-selected="folderIds.includes(entry.folder.id)"
        :class="row"
        @click="toggle(entry.folder.id)"
      >
        <span :class="box(folderIds.includes(entry.folder.id))" class="flex size-4.5 shrink-0 items-center justify-center rounded border" aria-hidden="true">
          <LayoutPaveIcon v-if="folderIds.includes(entry.folder.id)" name="check" class="size-3" />
        </span>
        <VaultFolderBadge :icon="entry.iconSrc" :color="entry.hex" />
        <span class="min-w-0 flex-1 truncate">{{ entry.folder.name }}</span>
      </button>
      <p v-if="!newFolderName && !vault.shelves.value.length" class="px-2.5 py-2 text-xs text-subtle">{{ VAULT_NO_FOLDER }}</p>
    </div>
  </div>
</template>
