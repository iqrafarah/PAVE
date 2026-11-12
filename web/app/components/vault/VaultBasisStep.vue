<script setup lang="ts">
// Step 1 "Basis" (Figma 1167:12715): upload the evidence, or add an experience without a file.
defineProps<{
  file: File | null;
}>();

const emit = defineEmits<{
  pick: [file: File];
  removeFile: [];
  withoutFile: [];
}>();

const problem = ref<string | null>(null);
const problemId = useId();

function pick(file: File) {
  problem.value = null;
  emit('pick', file);
}
</script>

<template>
  <div class="flex flex-col">
    <VaultFileChip v-if="file" :file="file" @remove="emit('removeFile')" />
    <VaultDropZone v-else kind="evidence" :described-by="problem ? problemId : undefined" @pick="pick" @problem="problem = $event" />
    <p v-if="problem" :id="problemId" role="alert" class="mt-2 text-xs text-danger">{{ problem }}</p>

    <div class="my-5.5 flex items-center gap-5.5" aria-hidden="true">
      <span class="h-px flex-1 rounded-lg bg-field-line" />
      <span class="text-xs font-semibold text-heading">{{ VAULT_OR }}</span>
      <span class="h-px flex-1 rounded-lg bg-field-line" />
    </div>

    <button
      type="button"
      class="flex min-h-23.5 w-full items-center gap-4 rounded-xl border border-field-line bg-white py-5 pl-23.5 pr-8 text-left hover:bg-surface focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-brand max-sm:pl-5"
      @click="emit('withoutFile')"
    >
      <span class="flex min-w-0 flex-1 flex-col gap-1">
        <span class="font-heading text-sm font-semibold text-heading">{{ VAULT_WITHOUT_FILE_TITLE }}</span>
        <span class="max-w-87.5 text-xs font-medium text-heading">{{ VAULT_WITHOUT_FILE_MESSAGE }}</span>
      </span>
      <img src="/images/vault/chevron-right.svg" alt="" width="8.14407" height="14.2767" />
    </button>
  </div>
</template>
