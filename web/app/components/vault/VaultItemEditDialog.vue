<script setup lang="ts">
import type { VaultItemDraft } from '~/types/vault';
import type { DraftField } from '~/utils/vaultAdd';

// Changing an item (iOS VaultItemEditor), with the same fields as step 2 of Kluis aanvullen plus the folder it is in.
// A confirmed item or one from an organisation keeps its content (the database refuses a change), so then only the
// folder can be chosen.
const props = defineProps<{
  itemId: string | null;
}>();

const emit = defineEmits<{
  close: [];
}>();

const vault = useVault();
const detailsRef = useTemplateRef<{ focusFirstProblem: (field: DraftField) => void }>('details');
const draft = ref<VaultItemDraft>(createDraft());
const folderId = ref<string | null>(null);
const folderFieldId = useId();
const showsProblems = ref(false);
const isSaving = ref(false);
const saveError = ref<string | null>(null);

const item = computed(() => vault.state.value.items.find((entry) => entry.id === props.itemId) ?? null);
const isOpen = computed({
  get: () => item.value !== null,
  set: (open) => {
    if (!open) emit('close');
  },
});
const canEditContent = computed(() => (item.value ? isEditable(item.value) : false));
// Only for the folder dropdown of a confirmed item; its kind does not change.
const lockedCategory = computed({
  get: () => item.value?.category ?? ('' as const),
  set: () => {},
});
const problems = computed(() => (showsProblems.value ? checkDraft(draft.value) : {}));

watch(
  item,
  (current, previous) => {
    if (!current || current.id === previous?.id) return;
    draft.value = {
      title: current.title,
      category: current.category,
      organisationName: current.organisationName ?? '',
      startMonth: current.startDate?.slice(0, 7) ?? '',
      endMonth: current.isCurrent ? '' : (current.endDate?.slice(0, 7) ?? ''),
      issuedMonth: current.issuedOn?.slice(0, 7) ?? '',
      description: current.description ?? '',
    };
    folderId.value = current.folderId;
    showsProblems.value = false;
    saveError.value = null;
  },
  { immediate: true },
);

async function save() {
  if (!item.value) return;
  if (!canEditContent.value) {
    isSaving.value = true;
    saveError.value = null;
    const isMoved = item.value.folderId === folderId.value || (await vault.move(item.value, folderId.value));
    isSaving.value = false;
    if (isMoved) emit('close');
    else {
      saveError.value = vault.state.value.problem;
      vault.state.value.problem = null;
    }
    return;
  }
  showsProblems.value = true;
  const missing = Object.keys(checkDraft(draft.value)) as DraftField[];
  if (missing.length) {
    detailsRef.value?.focusFirstProblem(missing[0]!);
    return;
  }
  isSaving.value = true;
  saveError.value = null;
  const isSaved = await vault.updateItem(item.value.id, draft.value, folderId.value);
  isSaving.value = false;
  if (!isSaved) {
    saveError.value = vault.state.value.problem;
    vault.state.value.problem = null;
    return;
  }
  emit('close');
}
</script>

<template>
  <VaultSheet v-model:open="isOpen" :title="VAULT_EDIT_TITLE">
    <VaultDetailsStep
      v-if="canEditContent"
      ref="details"
      v-model:draft="draft"
      v-model:folder-id="folderId"
      :file="null"
      :problems="problems"
      shows-folder
    />
    <div v-else class="flex flex-col gap-4">
      <p class="rounded-2xl bg-surface p-4 text-sm text-heading">{{ VAULT_EDIT_LOCKED }}</p>
      <VaultField :label="VAULT_FIELD_FOLDER" :for="folderFieldId">
        <VaultFolderSelect
          :id="folderFieldId"
          v-model:folder-id="folderId"
          v-model:category="lockedCategory"
          :can-change-category="false"
        />
      </VaultField>
    </div>
    <template #footer>
      <p v-if="saveError" role="alert" class="w-full text-sm text-danger">{{ saveError }}</p>
      <button
        type="button"
        :disabled="isSaving"
        class="min-h-10 min-w-25.75 rounded-field bg-field-line px-4 text-base font-medium text-heading hover:bg-tile focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-brand disabled:opacity-60"
        @click="emit('close')"
      >
        {{ VAULT_CANCEL }}
      </button>
      <button
        type="button"
        :disabled="isSaving"
        class="min-h-10 min-w-28.5 rounded-field bg-brand px-4 text-base font-medium text-white hover:bg-ink focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-brand disabled:opacity-60"
        @click="save"
      >
        {{ isSaving ? VAULT_SAVING : VAULT_SAVE }}
      </button>
    </template>
  </VaultSheet>
</template>
