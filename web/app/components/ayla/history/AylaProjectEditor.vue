<script setup lang="ts">
import type { VaultFolderColor, VaultFolderIcon } from '~/types/vault';

// Making or changing a project, in the window of "Kluis aanvullen" and "Nieuwe map" (VaultSheet): a large title, ✕ at
// the top right, the fields, and one green button at the bottom.
const props = defineProps<{
  title: string;
  confirmLabel: string;
  initialName: string;
  initialInstructions: string;
  initialIcon?: string | null;
  initialColor?: string | null;
  // Hidden until the icon/colour migration has run.
  canStyle?: boolean;
  isSaving?: boolean;
  // Set after a save that failed, so the window stays open and says so.
  error?: string | null;
}>();

const emit = defineEmits<{
  save: [name: string, instructions: string, icon: string | null, color: string | null];
  close: [];
}>();

const isOpen = ref(false);
const name = ref(props.initialName);
const instructions = ref(props.initialInstructions);
const icon = ref<VaultFolderIcon>(props.initialIcon && props.initialIcon in VAULT_FOLDER_ICONS ? (props.initialIcon as VaultFolderIcon) : 'folder');
const color = ref<VaultFolderColor | null>(props.initialColor && props.initialColor in VAULT_FOLDER_COLORS ? (props.initialColor as VaultFolderColor) : null);
const nameId = useId();
const instructionsId = useId();
const hintId = useId();

const canSave = computed(() => name.value.trim().length > 0 && !props.isSaving);

function save() {
  if (!canSave.value) return;
  emit('save', name.value.trim(), instructions.value.trim(), icon.value === 'folder' ? null : icon.value, color.value);
}

// The window opens once it is on the page, so the browser can show it as a dialog.
onMounted(() => (isOpen.value = true));
</script>

<template>
  <VaultSheet v-model:open="isOpen" :title="title" width="narrow" @close="emit('close')">
    <form class="flex flex-col gap-6" novalidate @submit.prevent="save">
      <!-- The folder of the project with its name, as it shows in the list. -->
      <div class="flex items-center gap-3.5 rounded-composer bg-tint px-4 py-3.5">
        <AylaProjectIconPicker v-if="canStyle" v-model:icon="icon" v-model:color="color" />
        <span v-else class="flex size-12 shrink-0 items-center justify-center rounded-pill bg-white text-brand">
          <VaultIcon src="/images/vault/icons/FolderClosedSolid.svg" class="size-6" />
        </span>
        <div class="flex min-w-0 flex-1 flex-col">
          <label :for="nameId" class="text-xs font-semibold text-subtle">{{ AYLA_PROJECT_NAME_LABEL }}</label>
          <input
            :id="nameId"
            v-model="name"
            type="text"
            :maxlength="AYLA_MAX_TITLE_LENGTH"
            autocomplete="off"
            autofocus
            :placeholder="AYLA_PROJECT_NAME_PLACEHOLDER"
            class="min-w-0 bg-transparent font-heading text-lg font-semibold text-heading placeholder:text-subtle/50 focus:outline-none"
          />
        </div>
      </div>

      <div class="flex flex-col">
        <div class="mb-2 flex items-baseline justify-between gap-3">
          <label :for="instructionsId" class="font-heading text-sm font-semibold text-heading">{{ AYLA_PROJECT_INSTRUCTIONS }}</label>
          <span class="text-xs text-subtle" aria-hidden="true">{{ instructions.length }}/{{ AYLA_PROJECT_INSTRUCTIONS_MAX }}</span>
        </div>
        <textarea
          :id="instructionsId"
          v-model="instructions"
          rows="6"
          :maxlength="AYLA_PROJECT_INSTRUCTIONS_MAX"
          :placeholder="AYLA_PROJECT_INSTRUCTIONS_PLACEHOLDER"
          :aria-describedby="hintId"
          class="resize-none rounded-bubble border border-field-line bg-white px-4 py-3.5 text-sm font-medium leading-relaxed text-heading placeholder:text-subtle/50 focus:border-brand focus:outline-none"
        />
        <p :id="hintId" class="mt-2 text-xs text-subtle">{{ AYLA_PROJECT_INSTRUCTIONS_HINT }}</p>
      </div>

      <p v-if="error" role="alert" class="text-xs text-danger">{{ error }}</p>
      <button type="submit" class="sr-only" tabindex="-1">{{ confirmLabel }}</button>
    </form>

    <template #footer>
      <button
        type="button"
        class="min-h-10.75 rounded-pill border border-line px-5 text-sm font-medium text-heading hover:bg-surface focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-brand"
        @click="isOpen = false; emit('close')"
      >
        {{ AYLA_CANCEL }}
      </button>
      <button
        type="button"
        :disabled="!canSave"
        class="min-h-10.75 rounded-pill bg-brand px-6 text-sm font-semibold text-white hover:bg-ink focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-brand disabled:opacity-60"
        @click="save"
      >
        {{ isSaving ? VAULT_SAVING : confirmLabel }}
      </button>
    </template>
  </VaultSheet>
</template>
