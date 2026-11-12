<script setup lang="ts">
// The dashed green field with the cloud (iOS VaultUploadZone): drop a file on it, or click it to choose one. Compact
// is one low row, for adding another file. The file is only checked here; nothing is uploaded before the last step.
const props = defineProps<{
  kind: 'evidence' | 'cover';
  isCompact?: boolean;
  // Other words than "Sleep een bestand hierheen…", such as "Nog een document toevoegen".
  title?: string;
  hint?: string;
  describedBy?: string;
}>();

const emit = defineEmits<{
  pick: [file: File];
  problem: [message: string];
}>();

const inputRef = useTemplateRef<HTMLInputElement>('input');
const isDraggingOver = ref(false);
const accept = computed(() => (props.kind === 'cover' ? VAULT_COVER_ACCEPT : VAULT_FILE_ACCEPT));

function take(file: File | undefined) {
  if (!file) return;
  const problem = checkVaultFile(file, props.kind);
  if (problem) emit('problem', problem);
  else emit('pick', file);
}

function handleChange(event: Event) {
  const input = event.target as HTMLInputElement;
  take(input.files?.[0]);
  input.value = '';
}

function handleDrop(event: DragEvent) {
  isDraggingOver.value = false;
  take(event.dataTransfer?.files[0]);
}
</script>

<template>
  <div>
    <input
      ref="input"
      type="file"
      :accept="accept"
      class="sr-only"
      tabindex="-1"
      aria-hidden="true"
      @change="handleChange"
    />
    <button
      type="button"
      :aria-describedby="describedBy"
      :class="[
        isCompact ? 'min-h-16 items-center gap-3 px-4 py-2.5 text-left' : 'min-h-48.5 flex-col items-center justify-center gap-3.5 p-5 text-center',
        isDraggingOver ? 'border-brand bg-tint' : 'border-drop-line bg-drop hover:bg-tint',
      ]"
      class="flex w-full rounded-xl border-2 border-dashed focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-brand"
      @click="inputRef?.click()"
      @dragenter.prevent="isDraggingOver = true"
      @dragover.prevent="isDraggingOver = true"
      @dragleave.prevent="isDraggingOver = false"
      @drop.prevent="handleDrop"
    >
      <VaultIcon src="/images/vault/icons/CloudArrowUpSolid.svg" :class="isCompact ? 'size-6' : 'size-13'" class="text-brand" />
      <span class="flex min-w-0 flex-col" :class="isCompact ? 'gap-0.5' : 'gap-1'">
        <span :class="isCompact ? 'text-sm' : 'text-base'" class="font-semibold text-heading">{{ title ?? VAULT_DROP_FILE }}</span>
        <span class="text-xs font-medium text-subtle">{{ hint ?? (kind === 'cover' ? VAULT_COVER_HINT : VAULT_UPLOAD_HINT) }}</span>
      </span>
    </button>
  </div>
</template>
