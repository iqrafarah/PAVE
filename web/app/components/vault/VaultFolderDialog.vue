<script setup lang="ts">
import type { VaultFolder, VaultFolderColor, VaultFolderIcon, VaultShelfEntry } from '~/types/vault';

// Making a folder or changing one (iOS VaultFolderEditor): a name, a colour and an icon, with the folder shown as it
// will look. A standard folder (Certificaten, Diploma's...) can be changed too; that is kept in your account.
const props = defineProps<{
  // Null while closed; 'new' for a new folder, or the folder to change.
  folder: VaultShelfEntry | 'new' | null;
}>();

const emit = defineEmits<{
  close: [];
  created: [folder: VaultFolder];
}>();

const vault = useVault();
const nameId = useId();
const problemId = useId();
const name = ref('');
const color = ref<VaultFolderColor>('green');
const icon = ref<VaultFolderIcon>('folder');
const problem = ref<string | null>(null);
const isSaving = ref(false);

const COLORS = Object.keys(VAULT_FOLDER_COLORS) as VaultFolderColor[];
const ICONS = Object.keys(VAULT_FOLDER_ICONS) as VaultFolderIcon[];

const editing = computed(() => (props.folder && props.folder !== 'new' ? props.folder : null));
const isOpen = computed({
  get: () => props.folder !== null,
  set: (open) => {
    if (!open) emit('close');
  },
});
const previewName = computed(() => name.value.trim() || VAULT_NEW_FOLDER_TITLE);
// A standard folder keeps its own icon (Stages: a building) until you choose another one.
const hasChosenIcon = ref(false);
const previewIcon = computed(() =>
  editing.value && !hasChosenIcon.value ? editing.value.iconSrc : VAULT_FOLDER_ICONS[icon.value],
);

watch(
  () => props.folder,
  (folder) => {
    if (!folder) return;
    name.value = folder === 'new' ? '' : folder.title;
    color.value = folder === 'new' ? 'green' : folder.colorKey;
    icon.value = folder === 'new' ? 'folder' : folder.iconKey;
    hasChosenIcon.value = false;
    problem.value = null;
  },
  { immediate: true },
);

watch(name, () => (problem.value = null));

async function save() {
  const trimmed = name.value.trim();
  if (!trimmed) {
    problem.value = VAULT_FOLDER_NAME_MISSING;
    return;
  }
  if (vault.isFolderNameTaken(trimmed, editing.value?.key)) {
    problem.value = VAULT_FOLDER_NAME_TAKEN;
    return;
  }
  isSaving.value = true;
  const target = editing.value;
  let isSaved: boolean;
  if (target?.shelf.kind === 'category') {
    const category = target.shelf.category;
    const isDefaultName = trimmed === VAULT_CATEGORY_PLURALS[category];
    const keepsIcon = hasChosenIcon.value || Boolean(vault.state.value.categoryFolders[category]?.icon);
    isSaved = await vault.updateCategoryFolder(category, {
      ...(isDefaultName ? {} : { name: trimmed }),
      ...(color.value === 'green' ? {} : { color: color.value }),
      ...(keepsIcon ? { icon: icon.value } : {}),
    });
  } else if (target?.shelf.kind === 'folder') {
    isSaved = await vault.updateFolder(target.shelf.id, trimmed, color.value, icon.value);
  } else {
    const created = await vault.createFolder(trimmed, color.value, icon.value);
    isSaving.value = false;
    if (created) emit('created', created);
    else takeProblem();
    return;
  }
  isSaving.value = false;
  if (isSaved) emit('close');
  else takeProblem();
}

/** A standard folder with its own icon (not one of the choices) has no choice lit up until you pick one. */
function isShownAsChosen(option: VaultFolderIcon) {
  return icon.value === option && previewIcon.value === VAULT_FOLDER_ICONS[option];
}

/** The reason it did not work is shown here, not in the toast of the vault. */
function takeProblem() {
  problem.value = vault.state.value.problem;
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
        :icon="previewIcon"
        :color="VAULT_FOLDER_COLORS[color]"
        :surface="folderSurface(color)"
        :count="editing ? editing.count : 0"
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
          class="h-11 rounded-field border border-field-line bg-white px-3.5 text-sm font-medium text-heading placeholder:text-subtle/50 focus:border-brand focus:outline-none aria-invalid:border-danger"
        />
        <p v-if="problem" :id="problemId" role="alert" class="mt-1.5 text-xs text-danger">{{ problem }}</p>
      </div>

      <fieldset class="flex flex-col">
        <legend class="mb-2.5 text-sm font-semibold text-heading">{{ VAULT_FOLDER_COLOR }}</legend>
        <div class="flex flex-wrap gap-1">
          <label
            v-for="option in COLORS"
            :key="option"
            class="flex size-11 cursor-pointer items-center justify-center rounded-full border-2 has-focus-visible:outline-2 has-focus-visible:outline-offset-1 has-focus-visible:outline-brand"
            :style="{ borderColor: color === option ? VAULT_FOLDER_COLORS[option] : 'transparent' }"
          >
            <input v-model="color" type="radio" name="vault-folder-color" :value="option" class="sr-only" />
            <span class="size-7.5 rounded-full" :style="{ background: VAULT_FOLDER_COLORS[option] }" aria-hidden="true" />
            <span class="sr-only">{{ VAULT_FOLDER_COLOR_TITLES[option] }}</span>
          </label>
        </div>
      </fieldset>

      <fieldset class="flex flex-col">
        <legend class="mb-2.5 text-sm font-semibold text-heading">{{ VAULT_FOLDER_ICON }}</legend>
        <div class="grid grid-cols-[repeat(auto-fill,minmax(2.75rem,1fr))] gap-2">
          <label
            v-for="option in ICONS"
            :key="option"
            :class="isShownAsChosen(option) ? 'text-white' : 'bg-tint text-heading hover:bg-brand-soft'"
            :style="isShownAsChosen(option) ? { background: VAULT_FOLDER_COLORS[color] } : undefined"
            class="flex h-11 cursor-pointer items-center justify-center rounded-[0.625rem] has-focus-visible:outline-2 has-focus-visible:outline-offset-1 has-focus-visible:outline-brand"
          >
            <input
              v-model="icon"
              type="radio"
              name="vault-folder-icon"
              :value="option"
              class="sr-only"
              @change="hasChosenIcon = true"
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
