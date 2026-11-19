<script setup lang="ts">
// Making or changing a project, in the window of "Kluis aanvullen" and "Nieuwe map" (VaultSheet): a large title, ✕ at
// the top right, the fields, and one green button at the bottom.
const props = defineProps<{
  title: string;
  confirmLabel: string;
  initialName: string;
  initialInstructions: string;
  isSaving?: boolean;
  // Set after a save that failed, so the window stays open and says so.
  error?: string | null;
}>();

const emit = defineEmits<{
  save: [name: string, instructions: string];
  close: [];
}>();

const isOpen = ref(false);
const name = ref(props.initialName);
const instructions = ref(props.initialInstructions);
const nameId = useId();
const instructionsId = useId();
const hintId = useId();

const canSave = computed(() => name.value.trim().length > 0 && !props.isSaving);

function save() {
  if (!canSave.value) return;
  emit('save', name.value.trim(), instructions.value.trim());
}

// The window opens once it is on the page, so the browser can show it as a dialog.
onMounted(() => (isOpen.value = true));
</script>

<template>
  <VaultSheet v-model:open="isOpen" :title="title" width="narrow" @close="emit('close')">
    <form class="flex flex-col gap-5.5" novalidate @submit.prevent="save">
      <div class="flex flex-col">
        <label :for="nameId" class="mb-2 text-sm font-semibold text-heading">{{ AYLA_PROJECT_NAME_LABEL }}</label>
        <input
          :id="nameId"
          v-model="name"
          type="text"
          :maxlength="AYLA_MAX_TITLE_LENGTH"
          autocomplete="off"
          autofocus
          :placeholder="AYLA_PROJECT_NAME_PLACEHOLDER"
          class="h-11 rounded-field border border-field-line bg-white px-3.5 text-sm font-medium text-heading placeholder:text-subtle/50 focus:border-brand focus:outline-none"
        />
      </div>

      <div class="flex flex-col">
        <label :for="instructionsId" class="mb-2 text-sm font-semibold text-heading">{{ AYLA_PROJECT_INSTRUCTIONS }}</label>
        <textarea
          :id="instructionsId"
          v-model="instructions"
          rows="5"
          :maxlength="AYLA_PROJECT_INSTRUCTIONS_MAX"
          :placeholder="AYLA_PROJECT_INSTRUCTIONS_PLACEHOLDER"
          :aria-describedby="hintId"
          class="resize-none rounded-field border border-field-line bg-white px-3.5 py-3 text-sm font-medium text-heading placeholder:text-subtle/50 focus:border-brand focus:outline-none"
        />
        <p :id="hintId" class="mt-1.5 text-xs text-subtle">{{ AYLA_PROJECT_INSTRUCTIONS_HINT }}</p>
      </div>

      <p v-if="error" role="alert" class="text-xs text-danger">{{ error }}</p>
      <button type="submit" class="sr-only" tabindex="-1">{{ confirmLabel }}</button>
    </form>

    <template #footer>
      <button
        type="button"
        :disabled="!canSave"
        class="min-h-10.75 w-full rounded-lg bg-brand text-base font-medium text-white hover:bg-ink focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-brand disabled:opacity-60"
        @click="save"
      >
        {{ isSaving ? VAULT_SAVING : confirmLabel }}
      </button>
    </template>
  </VaultSheet>
</template>
