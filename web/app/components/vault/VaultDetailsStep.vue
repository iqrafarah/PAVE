<script setup lang="ts">
import type { VaultItemCategory, VaultItemDraft } from '~/types/vault';
import type { DraftField } from '~/utils/vaultAdd';

// The details of evidence (Figma 1167:11759, iOS VaultEvidenceForm): the chosen files and what the evidence is about,
// with the folders it goes in. Every field but the folders is required, as in the design; what is missing shows once
// you press Volgende. Used for adding and for changing evidence.
withDefaults(
  defineProps<{
    files?: File[];
    problems: Partial<Record<DraftField, string>>;
    // A folder for the kind that does not exist yet ("Stages"), offered in Mappen; null when there is none.
    newFolderName?: string | null;
  }>(),
  { files: () => [], newFolderName: null },
);

const emit = defineEmits<{
  removeFile: [index: number];
  foldersChosen: [];
}>();

const draft = defineModel<VaultItemDraft>('draft', { required: true });
const folderIds = defineModel<string[]>('folderIds', { required: true });
const makesNewFolder = defineModel<boolean>('makesNewFolder', { default: false });

const ids = {
  title: useId(),
  category: useId(),
  organisation: useId(),
  period: useId(),
  description: useId(),
  folder: useId(),
};
const CATEGORIES = Object.entries(VAULT_CATEGORY_TITLES) as [VaultItemCategory, string][];
const withPeriod = computed(() => draftHasPeriod(draft.value));

function choosePeriod(isPeriod: boolean) {
  draft.value = { ...draft.value, usesPeriod: isPeriod };
}

const fieldClass =
  'h-9.75 w-full min-w-0 rounded-field border border-field-line bg-white px-3 text-sm font-medium text-heading focus:border-brand focus:outline-none aria-invalid:border-danger';

function problemId(field: string) {
  return `${field}-problem`;
}

defineExpose({ focusFirstProblem });

/** Puts the cursor in the first field that is missing, so a keyboard or screen reader user lands on it. */
function focusFirstProblem(field: DraftField) {
  const id = { title: ids.title, category: ids.category, organisationName: ids.organisation, period: ids.period, description: ids.description }[field];
  document.getElementById(id)?.focus();
}
</script>

<template>
  <div class="flex flex-col gap-4">
    <VaultFileChip v-for="(file, index) in files" :key="`${file.name}-${file.size}-${index}`" :file="file" @remove="emit('removeFile', index)" />

    <div class="grid gap-x-4.5 gap-y-4 sm:grid-cols-2">
      <VaultField :label="VAULT_FIELD_TITLE" :for="ids.title" :problem="problems.title" :problem-id="problemId(ids.title)">
        <input
          :id="ids.title"
          v-model="draft.title"
          type="text"
          maxlength="200"
          autocomplete="off"
          :aria-invalid="Boolean(problems.title)"
          :aria-describedby="problems.title ? problemId(ids.title) : undefined"
          :class="fieldClass"
        />
      </VaultField>

      <VaultField :label="VAULT_FIELD_CATEGORY" :for="ids.category" :problem="problems.category" :problem-id="problemId(ids.category)">
        <select
          :id="ids.category"
          v-model="draft.category"
          :aria-invalid="Boolean(problems.category)"
          :aria-describedby="problems.category ? problemId(ids.category) : undefined"
          :class="[fieldClass, draft.category ? '' : 'text-subtle/60']"
        >
          <option value="" disabled>{{ VAULT_FIELD_CATEGORY_PLACEHOLDER }}</option>
          <option v-for="[value, title] in CATEGORIES" :key="value" :value="value" class="text-heading">{{ title }}</option>
        </select>
      </VaultField>

      <VaultField :label="VAULT_FIELD_FOLDERS" :for="ids.folder" is-optional class="sm:col-span-2">
        <VaultFoldersPicker
          :id="ids.folder"
          v-model:folder-ids="folderIds"
          v-model:makes-new-folder="makesNewFolder"
          :new-folder-name="newFolderName"
          @chosen="emit('foldersChosen')"
        />
      </VaultField>

      <VaultField
        :label="VAULT_FIELD_ORGANISATION"
        :for="ids.organisation"
        :problem="problems.organisationName"
        :problem-id="problemId(ids.organisation)"
      >
        <input
          :id="ids.organisation"
          v-model="draft.organisationName"
          type="text"
          maxlength="200"
          autocomplete="organization"
          :aria-invalid="Boolean(problems.organisationName)"
          :aria-describedby="problems.organisationName ? problemId(ids.organisation) : undefined"
          :class="fieldClass"
        />
      </VaultField>

      <VaultField
        :label="withPeriod ? VAULT_FIELD_PERIOD : VAULT_FIELD_ISSUED"
        :for="ids.period"
        :problem="problems.period"
        :problem-id="problemId(ids.period)"
        is-group
      >
        <!-- A period or one date, for any kind; the kind only decides which comes first (as on iOS). It sits beside
             the label, so the field itself lines up with the one next to it. -->
        <template #aside>
          <div class="flex shrink-0 rounded-md bg-surface p-0.5" role="radiogroup" :aria-label="VAULT_FIELD_PERIOD_KIND">
            <button
              v-for="option in [true, false]"
              :key="String(option)"
              type="button"
              role="radio"
              :aria-checked="withPeriod === option"
              :class="withPeriod === option ? 'bg-white text-brand shadow-sm' : 'text-subtle hover:text-heading'"
              class="h-6 rounded px-2 text-[0.6875rem] font-semibold focus-visible:outline-2 focus-visible:outline-brand"
              @click="choosePeriod(option)"
            >
              {{ option ? VAULT_PERIOD_RANGE : VAULT_PERIOD_ONE_DATE }}
            </button>
          </div>
        </template>
        <div
          v-if="withPeriod"
          role="group"
          :aria-labelledby="`${ids.period}-label`"
          :aria-describedby="problems.period ? problemId(ids.period) : undefined"
          :class="problems.period ? 'border-danger' : 'border-field-line focus-within:border-brand'"
          class="flex h-9.75 items-center gap-1 rounded-field border bg-white px-2"
        >
          <label :for="ids.period" class="sr-only">{{ VAULT_FIELD_START }}</label>
          <input
            :id="ids.period"
            v-model="draft.startMonth"
            type="month"
            :max="draft.endMonth || undefined"
            class="min-w-0 flex-1 bg-transparent text-xs font-medium text-heading focus:outline-none"
          />
          <span class="text-subtle" aria-hidden="true">–</span>
          <label :for="`${ids.period}-end`" class="sr-only">{{ VAULT_FIELD_END }} ({{ VAULT_FIELD_END_HINT }})</label>
          <input
            :id="`${ids.period}-end`"
            v-model="draft.endMonth"
            type="month"
            :min="draft.startMonth || undefined"
            :title="VAULT_FIELD_END_HINT"
            class="min-w-0 flex-1 bg-transparent text-xs font-medium text-heading focus:outline-none"
          />
        </div>
        <input
          v-else
          :id="ids.period"
          v-model="draft.issuedMonth"
          type="month"
          :aria-labelledby="`${ids.period}-label`"
          :aria-invalid="Boolean(problems.period)"
          :aria-describedby="problems.period ? problemId(ids.period) : undefined"
          :class="fieldClass"
        />
      </VaultField>
    </div>

    <VaultField
      :label="VAULT_FIELD_DESCRIPTION"
      :for="ids.description"
      :problem="problems.description"
      :problem-id="problemId(ids.description)"
    >
      <textarea
        :id="ids.description"
        v-model="draft.description"
        rows="4"
        :aria-invalid="Boolean(problems.description)"
        :aria-describedby="problems.description ? problemId(ids.description) : undefined"
        class="h-28.5 w-full resize-none rounded-field border border-field-line bg-white px-3 py-2.5 text-sm font-medium text-heading focus:border-brand focus:outline-none aria-invalid:border-danger"
      />
    </VaultField>
  </div>
</template>
