<script setup lang="ts">
// Step 1 "Basis" (Figma 1167:12715): upload the evidence, or add an experience without a file. As on iOS, a picked file
// keeps you on this step, so you can add more (up to five) before going on with Volgende.
const props = defineProps<{
  files: File[];
}>();

const emit = defineEmits<{
  pick: [file: File];
  removeFile: [index: number];
  withoutFile: [];
}>();

const problem = ref<string | null>(null);
const problemId = useId();
const canAddMore = computed(() => props.files.length < MAX_DOCUMENTS);

function pick(file: File) {
  problem.value = null;
  emit('pick', file);
}
</script>

<template>
  <div class="flex flex-col">
    <template v-if="files.length">
      <div class="flex flex-col gap-2.5">
        <VaultFileChip v-for="(file, index) in files" :key="`${file.name}-${file.size}-${index}`" :file="file" @remove="emit('removeFile', index)" />
      </div>
      <VaultDropZone
        v-if="canAddMore"
        class="mt-3"
        kind="evidence"
        is-compact
        :title="VAULT_ADD_ANOTHER_DOCUMENT"
        :described-by="problem ? problemId : undefined"
        @pick="pick"
        @problem="problem = $event"
      />
      <p v-else class="mt-3 text-xs text-subtle">{{ VAULT_DOCUMENTS_FULL(MAX_DOCUMENTS) }}</p>
      <p v-if="problem" :id="problemId" role="alert" class="mt-2 text-xs text-danger">{{ problem }}</p>
    </template>

    <template v-else>
      <VaultDropZone kind="evidence" :described-by="problem ? problemId : undefined" @pick="pick" @problem="problem = $event" />
      <p v-if="problem" :id="problemId" role="alert" class="mt-2 text-xs text-danger">{{ problem }}</p>

      <div class="my-5.5 flex items-center gap-5.5" aria-hidden="true">
        <span class="h-px flex-1 rounded-lg bg-field-line" />
        <span class="text-xs font-semibold text-heading">{{ VAULT_OR }}</span>
        <span class="h-px flex-1 rounded-lg bg-field-line" />
      </div>

      <button
        type="button"
        class="flex w-full items-center gap-3 rounded-xl border border-field-line bg-white p-5 text-left hover:bg-surface focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-brand"
        @click="emit('withoutFile')"
      >
        <span class="flex min-w-0 flex-1 flex-col gap-1">
          <span class="text-sm font-semibold text-heading">{{ VAULT_WITHOUT_FILE_TITLE }}</span>
          <span class="text-xs font-medium text-subtle">{{ VAULT_WITHOUT_FILE_MESSAGE }}</span>
        </span>
        <img src="/images/vault/chevron-right.svg" alt="" width="8.14407" height="14.2767" />
      </button>
    </template>
  </div>
</template>
