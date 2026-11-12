<script setup lang="ts">
// A window over the vault in the style of "Kluis aanvullen": a white card with a large title, ✕ at the top right and
// the buttons at the bottom. Escape or a click next to it closes it.
withDefaults(
  defineProps<{
    title: string;
    width?: 'narrow' | 'wide';
  }>(),
  { width: 'wide' },
);

const isOpen = defineModel<boolean>('open', { required: true });
const emit = defineEmits<{
  close: [];
}>();

const dialogRef = useTemplateRef<HTMLDialogElement>('dialog');
const titleId = useId();

watch(
  isOpen,
  (open) => {
    if (!import.meta.client) return;
    if (open && !dialogRef.value?.open) dialogRef.value?.showModal();
    if (!open && dialogRef.value?.open) dialogRef.value.close();
  },
  { flush: 'post' },
);

function requestClose() {
  isOpen.value = false;
  emit('close');
}

function handleCancel(event: Event) {
  event.preventDefault();
  requestClose();
}

function handleClick(event: MouseEvent) {
  if (event.target === dialogRef.value) requestClose();
}

</script>

<template>
  <dialog
    ref="dialog"
    :aria-labelledby="titleId"
    :class="width === 'narrow' ? 'max-w-120' : 'max-w-154'"
    class="m-auto max-h-[calc(100dvh-2rem)] w-[calc(100%-2rem)] overflow-hidden rounded-modal bg-white p-0 text-heading shadow-modal backdrop:bg-backdrop"
    @cancel="handleCancel"
    @click="handleClick"
  >
    <div v-if="isOpen" class="flex max-h-[calc(100dvh-2rem)] flex-col">
      <div class="flex items-start justify-between gap-4 px-9 pt-8 max-sm:px-5">
        <h2 :id="titleId" class="min-w-0 font-heading text-2xl font-semibold text-heading">{{ title }}</h2>
        <button
          type="button"
          :aria-label="VAULT_ADD_CLOSE"
          :title="VAULT_ADD_CLOSE"
          class="flex h-9.25 w-8.75 shrink-0 items-center justify-center rounded-field border border-field-line hover:bg-surface focus-visible:outline-2 focus-visible:outline-brand"
          @click="requestClose"
        >
          <img src="/images/vault/close.svg" alt="" width="13.6909" height="13.6909" />
        </button>
      </div>
      <div tabindex="-1" autofocus class="min-h-0 flex-1 overflow-y-auto px-9 pb-1 pt-6 focus:outline-none max-sm:px-5">
        <slot />
      </div>
      <div v-if="$slots.footer" class="flex flex-wrap justify-end gap-2.5 px-9 pb-8 pt-6 max-sm:px-5">
        <slot name="footer" />
      </div>
    </div>
  </dialog>
</template>
