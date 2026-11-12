<script setup lang="ts">
// A confirmation like iOS's confirmationDialog: a small title (and message) above the red action, with "Annuleren"
// in its own card. At the bottom of the screen on phones, in the middle on wider screens. Escape cancels.
defineProps<{
  title: string;
  message?: string;
  confirmLabel: string;
}>();

const emit = defineEmits<{
  confirm: [];
}>();

const dialogRef = useTemplateRef<HTMLDialogElement>('dialog');
const titleId = useId();
const messageId = useId();

function open() {
  dialogRef.value?.showModal();
}

function close() {
  dialogRef.value?.close();
}

function confirm() {
  close();
  emit('confirm');
}

// A click on the dimmed backdrop (the dialog element itself) cancels, as on iOS.
function handleClick(event: MouseEvent) {
  if (event.target === dialogRef.value) close();
}

defineExpose({ open });
</script>

<template>
  <dialog
    ref="dialog"
    :aria-labelledby="titleId"
    :aria-describedby="message ? messageId : undefined"
    class="m-auto w-full max-w-sm bg-transparent p-2 backdrop:bg-ink/40 max-sm:mb-0 max-sm:max-w-none"
    @click="handleClick"
  >
    <div class="overflow-hidden rounded-2xl bg-white text-center">
      <div class="px-4 py-3.5">
        <h2 :id="titleId" class="text-xs font-semibold text-subtle">{{ title }}</h2>
        <p v-if="message" :id="messageId" class="mt-1 text-xs/normal text-subtle">{{ message }}</p>
      </div>
      <button
        type="button"
        class="min-h-14 w-full border-t border-line text-base font-medium text-danger hover:bg-surface focus-visible:outline-2 focus-visible:-outline-offset-2 focus-visible:outline-brand"
        @click="confirm"
      >
        {{ confirmLabel }}
      </button>
    </div>
    <button
      type="button"
      class="mt-2 min-h-14 w-full rounded-2xl bg-white text-base font-semibold text-brand hover:bg-surface focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-brand"
      @click="close"
    >
      {{ AYLA_CANCEL }}
    </button>
  </dialog>
</template>
