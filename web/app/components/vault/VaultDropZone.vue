<script setup lang="ts">
// The dashed green field (Figma "Sleep bestand hierheen of klik om te uploaden"): drop a file on it, or click it to
// choose one. The file is only checked here; nothing is uploaded before the last step.
const props = defineProps<{
  kind: 'evidence' | 'cover';
  isCompact?: boolean;
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
        isCompact ? 'min-h-43.5 pt-4.5' : 'min-h-56.5 pt-8.25',
        isDraggingOver ? 'border-brand bg-tint' : 'border-drop-line bg-drop hover:bg-tint',
      ]"
      class="flex w-full flex-col items-center rounded-xl border-2 border-dashed px-4 pb-5 text-center focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-brand"
      @click="inputRef?.click()"
      @dragenter.prevent="isDraggingOver = true"
      @dragover.prevent="isDraggingOver = true"
      @dragleave.prevent="isDraggingOver = false"
      @drop.prevent="handleDrop"
    >
      <img src="/images/vault/upload-cloud.svg" alt="" width="89.2203" height="94" />
      <span class="mt-1.5 font-heading text-base font-semibold text-heading">{{ VAULT_DROP_FILE }}</span>
    </button>
  </div>
</template>
