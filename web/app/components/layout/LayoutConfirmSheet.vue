<script setup lang="ts">
// A confirmation in the middle of the screen: the question, what it means, and two buttons next to each other, the safe
// one first (it has the focus) and the red action last. Escape or a click next to the card cancels.
// With a second choice (`alternativeLabel`) the three buttons stand under each other, the safe one last but focused.
const props = defineProps<{
  title: string;
  message?: string;
  confirmLabel: string;
  // What staying is called, such as "Verder met toevoegen"; "Annuleren" when left out.
  cancelLabel?: string;
  // The action is not destructive (saving, for instance): green instead of red.
  isCalm?: boolean;
  // Another way forward next to the main one, such as "Vragen zonder toestemming".
  alternativeLabel?: string;
}>();

const emit = defineEmits<{
  confirm: [];
  alternative: [];
}>();

const dialogRef = useTemplateRef<HTMLDialogElement>('dialog');
const titleId = useId();
const messageId = useId();

const cancelButton =
  'min-h-10 whitespace-nowrap rounded-field bg-field-line px-4 text-sm font-medium text-heading hover:bg-tile focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-brand';
const confirmButton = computed(() => [
  props.isCalm ? 'bg-brand hover:bg-ink' : 'bg-danger hover:opacity-90',
  'min-h-10 whitespace-nowrap rounded-field px-4 text-sm font-medium text-white focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-brand',
]);
const alternativeButton =
  'min-h-10 whitespace-nowrap rounded-field border-[1.5px] border-brand bg-white px-4 text-sm font-medium text-brand hover:bg-tint focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-brand';

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

function chooseAlternative() {
  close();
  emit('alternative');
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
    <div v-if="alternativeLabel" class="mt-6 flex flex-col gap-2.5">
      <button type="button" :class="confirmButton" @click="confirm">{{ confirmLabel }}</button>
      <button type="button" :class="alternativeButton" @click="chooseAlternative">{{ alternativeLabel }}</button>
      <button type="button" autofocus :class="cancelButton" @click="close">{{ cancelLabel ?? AYLA_CANCEL }}</button>
    </div>
    <div v-else class="mt-6 flex flex-wrap justify-end gap-2.5">
      <button type="button" autofocus :class="cancelButton" class="flex-1" @click="close">
        {{ cancelLabel ?? AYLA_CANCEL }}
      </button>
      <button type="button" :class="confirmButton" class="flex-1" @click="confirm">{{ confirmLabel }}</button>
    </div>
  </dialog>
</template>
