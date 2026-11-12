<script setup lang="ts">
import type { VaultItemCategory, VaultItemDraft } from '~/types/vault';
import type { DraftField } from '~/utils/vaultAdd';

// Step 2 "Documenten" (Figma 1167:11759): the chosen file and what the evidence is about. Every field is required,
// as in the design; what is missing shows once you press Volgende.
withDefaults(
  defineProps<{
    file: File | null;
    problems: Partial<Record<DraftField, string>>;
    // Shows "Map" next to "Soort"; off where the folder is not chosen.
    showsFolder?: boolean;
  }>(),
  { showsFolder: false },
);

const emit = defineEmits<{
  removeFile: [];
}>();

const draft = defineModel<VaultItemDraft>('draft', { required: true });
const folderId = defineModel<string | null>('folderId', { default: null });

const ids = {
  title: useId(),
  category: useId(),
  organisation: useId(),
  period: useId(),
  description: useId(),
  folder: useId(),
};
const CATEGORIES = Object.entries(VAULT_CATEGORY_TITLES) as [VaultItemCategory, string][];
const withPeriod = computed(() => hasPeriod(draft.value.category));

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
    <VaultFileChip v-if="file" class="mb-1.5" :file="file" @remove="emit('removeFile')" />

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

      <VaultField v-if="showsFolder" :label="VAULT_FIELD_FOLDER" :for="ids.folder" class="sm:col-span-2">
        <VaultFolderSelect :id="ids.folder" v-model:folder-id="folderId" v-model:category="draft.category" can-change-category />
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
        <!-- Something you did for a while has a start and an end; a diploma or certificate has one month. -->
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
