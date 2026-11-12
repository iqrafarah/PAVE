<script setup lang="ts">
import type { VaultFile } from '~/types/vault';

// "Documenten" (iOS VaultDocumentsSection): the files that prove the evidence, saved ones and new ones, up to five.
// Every one can be taken away, and another can be added while there is room.
const props = withDefaults(
  defineProps<{
    saved?: VaultFile[];
    files: File[];
  }>(),
  { saved: () => [] },
);

const emit = defineEmits<{
  pick: [file: File];
  removeSaved: [file: VaultFile];
  removeFile: [index: number];
}>();

const problem = ref<string | null>(null);
const problemId = useId();
const titleId = useId();
const count = computed(() => props.saved.length + props.files.length);
</script>

<template>
  <section :aria-labelledby="titleId" class="flex flex-col gap-2.5">
    <h3 :id="titleId" class="text-base font-semibold text-heading">{{ VAULT_DOCUMENTS }}</h3>
    <p v-if="!count" class="text-xs text-subtle">{{ VAULT_DOCUMENTS_EMPTY }}</p>
    <div
      v-for="file in saved"
      :key="file.id"
      class="flex min-h-14 items-center gap-3.5 rounded-xl bg-tint py-2 pl-3 pr-2"
    >
      <VaultIcon src="/images/vault/icons/DocumentSolid.svg" class="size-6 text-brand" />
      <span class="min-w-0 flex-1 truncate text-sm font-semibold text-heading">{{ file.name }}</span>
      <button
        type="button"
        :aria-label="`${VAULT_REMOVE_FILE}: ${file.name}`"
        class="flex size-8 items-center justify-center rounded-lg text-subtle hover:bg-white hover:text-danger focus-visible:outline-2 focus-visible:outline-brand"
        @click="emit('removeSaved', file)"
      >
        <VaultIcon src="/images/vault/icons/Trash.svg" class="size-4.5" />
      </button>
    </div>
    <VaultFileChip v-for="(file, index) in files" :key="`${file.name}-${file.size}-${index}`" :file="file" @remove="emit('removeFile', index)" />
    <VaultDropZone
      v-if="count < MAX_DOCUMENTS"
      kind="evidence"
      is-compact
      :title="count ? VAULT_ADD_ANOTHER_DOCUMENT : VAULT_ADD_DOCUMENT"
      :described-by="problem ? problemId : undefined"
      @pick="problem = null; emit('pick', $event)"
      @problem="problem = $event"
    />
    <p v-else class="text-xs text-subtle">{{ VAULT_DOCUMENTS_FULL(MAX_DOCUMENTS) }}</p>
    <p v-if="problem" :id="problemId" role="alert" class="text-xs text-danger">{{ problem }}</p>
  </section>
</template>
