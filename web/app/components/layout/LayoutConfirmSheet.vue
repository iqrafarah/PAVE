<script setup lang="ts">
// A confirmation in the middle of the screen: the question, what it means, and two buttons next to each other, the safe
// one first (it has the focus) and the red action last. Escape or a click next to the card cancels.
defineProps<{
  title: string;
  message?: string;
  confirmLabel: string;
  // What staying is called, such as "Verder met toevoegen"; "Annuleren" when left out.
  cancelLabel?: string;
  // The action is not destructive (saving, for instance): green instead of red.
  isCalm?: boolean;
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
    class="m-auto w-[calc(100%-2rem)] max-w-110 rounded-2xl bg-white p-6 text-left shadow-modal backdrop:bg-backdrop"
    @click="handleClick"
  >
    <h2 :id="titleId" class="font-heading text-lg font-semibold text-heading">{{ title }}</h2>
    <p v-if="message" :id="messageId" class="mt-2 text-sm font-medium text-subtle">{{ message }}</p>
    <div class="mt-6 flex flex-wrap justify-end gap-2.5">
      <button
        type="button"
        autofocus
        class="min-h-10 flex-1 whitespace-nowrap rounded-field bg-field-line px-4 text-sm font-medium text-heading hover:bg-tile focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-brand"
        @click="close"
      >
        {{ cancelLabel ?? AYLA_CANCEL }}
      </button>
      <button
        type="button"
        :class="isCalm ? 'bg-brand hover:bg-ink' : 'bg-danger hover:opacity-90'"
        class="min-h-10 flex-1 whitespace-nowrap rounded-field px-4 text-sm font-medium text-white focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-brand"
        @click="confirm"
      >
        {{ confirmLabel }}
      </button>
    </div>
  </dialog>
</template>
