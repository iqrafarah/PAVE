<script setup lang="ts">
import type { VaultFolder, VaultFolderColorChoice, VaultFolderHex, VaultFolderIcon } from '~/types/vault';

// Making a folder or changing one (iOS VaultFolderEditor): a name, a colour (one of the list or one of your own) and an
// icon, with the folder shown as it will look. The four example folders are ordinary folders, so they change the same way.
const props = defineProps<{
  // Null while closed; 'new' for a new folder, or the folder to change.
  folder: VaultFolder | 'new' | null;
}>();

const emit = defineEmits<{
  close: [];
  created: [folder: VaultFolder];
}>();

const vault = useVault();
const nameId = useId();
const problemId = useId();
const name = ref('');
const color = ref<VaultFolderColorChoice>('green');
// The colour of your own stays remembered while you try the named ones, so you can go back to it.
const DEFAULT_CUSTOM_COLOR: VaultFolderHex = '#c2410c';
const customColor = ref<VaultFolderHex>(DEFAULT_CUSTOM_COLOR);
const isCustom = computed(() => isFolderHex(color.value));
// Whether there is a colour of your own to go back to (this folder has one, or you picked one just now).
const hasPickedCustom = ref(false);
const icon = ref<VaultFolderIcon>('folder');
const problem = ref<string | null>(null);
const colorProblem = ref<string | null>(null);
const isSaving = ref(false);

const COLORS = VAULT_FOLDER_PICKER_COLORS;
const ICONS = Object.keys(VAULT_FOLDER_ICONS) as VaultFolderIcon[];

const editing = computed(() => (props.folder && props.folder !== 'new' ? props.folder : null));
const isOpen = computed({
  get: () => props.folder !== null,
  set: (open) => {
    if (!open) emit('close');
  },
});
const previewName = computed(() => name.value.trim() || VAULT_NEW_FOLDER_TITLE);

watch(
  () => props.folder,
  (folder) => {
    if (!folder) return;
    // A new folder starts in the colour of the theme; one of your own colour keeps it for going back to.
    const style = folder === 'new' ? null : folderStyle(folder, vault.defaultFolderColor.value);
    const start = style?.color ?? vault.defaultFolderColor.value;
    name.value = folder === 'new' ? '' : folder.name;
    color.value = start;
    customColor.value = isFolderHex(start) ? start : DEFAULT_CUSTOM_COLOR;
    hasPickedCustom.value = isFolderHex(start);
    icon.value = style?.icon ?? 'folder';
    problem.value = null;
    colorProblem.value = null;
  },
  { immediate: true },
);

watch(name, () => (problem.value = null));
watch(color, () => (colorProblem.value = null));

function pickCustom(event: Event) {
  const value = (event.target as HTMLInputElement).value.toLowerCase();
  if (!isFolderHex(value)) return;
  customColor.value = value;
  hasPickedCustom.value = true;
  color.value = value;
}

async function save() {
  const trimmed = name.value.trim();
  if (!trimmed) {
    problem.value = VAULT_FOLDER_NAME_MISSING;
    return;
  }
  if (vault.isFolderNameTaken(trimmed, editing.value?.id)) {
    problem.value = VAULT_FOLDER_NAME_TAKEN;
    return;
  }
  isSaving.value = true;
  if (editing.value) {
    const isSaved = await vault.updateFolder(editing.value.id, trimmed, color.value, icon.value);
    isSaving.value = false;
    if (isSaved) emit('close');
    else takeProblem();
    return;
  }
  const created = await vault.createFolder(trimmed, color.value, icon.value);
  isSaving.value = false;
  if (created) emit('created', created);
  else takeProblem();
}

/** The reason it did not work is shown here, not in the toast of the vault. */
function takeProblem() {
  const message = vault.state.value.problem;
  if (message === VAULT_FOLDER_COLOR_NOT_READY) colorProblem.value = message;
  else problem.value = message;
  vault.state.value.problem = null;
}
</script>

<template>
  <VaultSheet v-model:open="isOpen" :title="editing ? VAULT_EDIT_FOLDER_TITLE : VAULT_NEW_FOLDER_TITLE" width="narrow">
    <form class="flex flex-col gap-6" @submit.prevent="save">
      <VaultFolderTile
        class="pointer-events-none mx-auto max-w-40"
        aria-hidden="true"
        inert
        :title="previewName"
        :icon="VAULT_FOLDER_ICONS[icon]"
        :color="folderHex(color)"
        :surface="folderSurface(color)"
        :icon-color="folderIconColor(color)"
        :count="editing ? vault.count({ kind: 'folder', id: editing.id }) : 0"
      />

      <div class="flex flex-col">
        <label :for="nameId" class="mb-2 text-sm font-semibold text-heading">{{ VAULT_FOLDER_NAME }}</label>
        <input
          :id="nameId"
          v-model="name"
          type="text"
          maxlength="100"
          autocomplete="off"
          :placeholder="VAULT_FOLDER_NAME_PLACEHOLDER"
          :aria-invalid="Boolean(problem)"
          :aria-describedby="problem ? problemId : undefined"
          class="h-11 rounded-field border border-field-line bg-white px-3.5 text-sm font-medium text-heading placeholder:text-subtle/50 focus:border-subtle focus:outline-none aria-invalid:border-danger"
        />
        <p v-if="problem" :id="problemId" role="alert" class="mt-1.5 text-xs text-danger">{{ problem }}</p>
      </div>

      <fieldset class="flex flex-col">
        <legend class="mb-2.5 text-sm font-semibold text-heading">{{ VAULT_FOLDER_COLOR }}</legend>
        <div class="flex justify-between">
          <label
            v-for="option in COLORS"
            :key="option"
            class="flex aspect-square min-w-0 max-w-11 flex-1 cursor-pointer items-center justify-center rounded-full border-2 has-focus-visible:outline-2 has-focus-visible:outline-offset-1 has-focus-visible:outline-brand"
            :style="{ borderColor: color === option ? VAULT_FOLDER_COLORS[option] : 'transparent' }"
          >
            <input v-model="color" type="radio" name="vault-folder-color" :value="option" class="sr-only" />
            <span class="size-7.5 rounded-full" :style="{ background: VAULT_FOLDER_COLORS[option] }" aria-hidden="true" />
            <span class="sr-only">{{ VAULT_FOLDER_COLOR_TITLES[option] }}</span>
          </label>
          <!-- A colour of your own, as in Settings: the colour wheel until it is chosen, with the last own colour in the
               middle once there is one; chosen, it looks like the other colours. -->
          <label
            :title="VAULT_FOLDER_CUSTOM_COLOR"
            :style="{ borderColor: isCustom ? customColor : 'transparent' }"
            class="relative flex aspect-square min-w-0 max-w-11 flex-1 cursor-pointer items-center justify-center rounded-full border-2 focus-within:outline-2 focus-within:outline-offset-1 focus-within:outline-brand"
          >
            <span v-if="isCustom" class="size-7.5 rounded-full" :style="{ background: customColor }" aria-hidden="true" />
            <span v-else class="flex size-7.5 items-center justify-center rounded-full bg-(image:--background-image-color-wheel)" aria-hidden="true">
              <span v-if="hasPickedCustom" class="size-3.5 rounded-full border-2 border-white shadow-sm" :style="{ background: customColor }" />
            </span>
            <input
              type="color"
              :value="customColor"
              :aria-label="VAULT_FOLDER_CUSTOM_COLOR"
              class="absolute inset-0 size-full cursor-pointer rounded-full opacity-0"
              @input="pickCustom"
              @click="hasPickedCustom && (color = customColor)"
            />
          </label>
        </div>
        <p v-if="colorProblem" role="alert" class="mt-1.5 text-xs text-danger">{{ colorProblem }}</p>
      </fieldset>

      <fieldset class="flex flex-col">
        <legend class="mb-2.5 text-sm font-semibold text-heading">{{ VAULT_FOLDER_ICON }}</legend>
        <div class="grid grid-cols-[repeat(auto-fill,minmax(2.75rem,1fr))] gap-2">
          <label
            v-for="option in ICONS"
            :key="option"
            :class="icon === option ? '' : 'bg-tint text-heading hover:bg-brand-soft'"
            :style="icon === option ? { background: folderHex(color), color: folderIconColor(color) } : undefined"
            class="flex h-11 cursor-pointer items-center justify-center rounded-[0.625rem] has-focus-visible:outline-2 has-focus-visible:outline-offset-1 has-focus-visible:outline-brand"
          >
            <input
              v-model="icon"
              type="radio"
              name="vault-folder-icon"
              :value="option"
              class="sr-only"
            />
            <VaultIcon :src="VAULT_FOLDER_ICONS[option]" class="size-5" />
            <span class="sr-only">{{ VAULT_FOLDER_ICON_TITLES[option] }}</span>
          </label>
        </div>
      </fieldset>
    </form>

    <template #footer>
      <button
        type="button"
        :disabled="isSaving"
        class="min-h-10.75 w-full rounded-lg bg-brand text-base font-medium text-white hover:bg-ink focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-brand disabled:opacity-60"
        @click="save"
      >
        {{ isSaving ? VAULT_SAVING : editing ? VAULT_SAVE : VAULT_FOLDER_CREATE }}
      </button>
    </template>
  </VaultSheet>
</template>
