<script setup lang="ts">
// The PIN window for locked chats, in the window of "Kluis aanvullen" (VaultSheet): a lock, a title, a few lines and
// the PIN field, drawn like the code field of two-step verification.
// 'create' asks twice; 'enter' asks once and offers "Pincode vergeten?".
const props = defineProps<{
  mode: 'create' | 'enter';
  // Said under the boxes after the parent checked the PIN.
  error?: string | null;
  isBusy?: boolean;
  // "Pincode wijzigen" in Privacy: first the current PIN, then the new one, with their own words.
  isChange?: boolean;
}>();

const emit = defineEmits<{
  complete: [pin: string];
  forgot: [];
  close: [];
}>();

const isOpen = ref(false);
const digits = ref('');
const firstPin = ref<string | null>(null);
const mismatch = ref(false);
const fieldRef = useTemplateRef<{ focus: () => void }>('field');
const inputId = useId();
const errorId = useId();

const isConfirming = computed(() => props.mode === 'create' && firstPin.value !== null);
const title = computed(() => {
  if (props.mode === 'enter') return props.isChange ? ACCOUNT_PIN_CURRENT_TITLE : AYLA_PIN_ENTER_TITLE;
  if (props.isChange && !isConfirming.value) return ACCOUNT_PIN_NEW_TITLE;
  return isConfirming.value ? AYLA_PIN_CONFIRM_TITLE : AYLA_PIN_CREATE_TITLE;
});
const body = computed(() => {
  if (props.mode === 'enter') return props.isChange ? ACCOUNT_PIN_CURRENT_BODY : AYLA_PIN_ENTER_BODY;
  if (props.isChange && !isConfirming.value) return ACCOUNT_PIN_NEW_BODY;
  return isConfirming.value ? AYLA_PIN_CONFIRM_BODY : AYLA_PIN_CREATE_BODY;
});
const shownError = computed(() => (mismatch.value ? AYLA_PIN_MISMATCH : props.error));

// Typing again after a mismatch takes the message away.
watch(digits, (value) => value && (mismatch.value = false));

function onComplete(pin: string) {
  if (props.mode === 'create' && firstPin.value === null) {
    firstPin.value = pin;
    clear();
  } else if (props.mode === 'create' && pin !== firstPin.value) {
    firstPin.value = null;
    mismatch.value = true;
    clear();
  } else {
    emit('complete', pin);
  }
}

/** Empties the boxes, for instance after a wrong PIN. */
function clear() {
  digits.value = '';
  fieldRef.value?.focus();
}

watch(
  () => props.error,
  (error) => error && clear(),
);

onMounted(async () => {
  isOpen.value = true;
  await nextTick();
  fieldRef.value?.focus();
});

defineExpose({ clear });
</script>

<template>
  <VaultSheet v-model:open="isOpen" :title="title" width="narrow" hides-title @close="emit('close')">
    <div class="flex flex-col items-center gap-5 pb-4 text-center">
      <span class="flex size-18 items-center justify-center rounded-full bg-tint text-brand" aria-hidden="true">
        <LayoutPaveIcon name="lock" class="size-8" />
      </span>
      <div class="-mt-1 flex flex-col gap-2">
        <p class="font-heading text-2xl font-semibold text-heading" aria-hidden="true">{{ title }}</p>
        <p class="max-w-95 text-sm font-medium text-subtle">{{ body }}</p>
      </div>

      <!-- The same boxes as the code of two-step verification, with dots instead of digits. -->
      <div class="w-full">
        <label :for="inputId" class="sr-only">{{ AYLA_PIN_LABEL }}</label>
        <LayoutCodeField
          :id="inputId"
          ref="field"
          v-model="digits"
          class="justify-center"
          :length="AYLA_PIN_LENGTH"
          is-masked
          :is-disabled="isBusy"
          :is-invalid="Boolean(shownError)"
          :described-by="shownError ? errorId : undefined"
          @complete="onComplete"
        />
        <p v-if="shownError" :id="errorId" role="alert" class="mt-2 text-sm text-danger">{{ shownError }}</p>
      </div>

      <button
        v-if="mode === 'enter'"
        type="button"
        class="text-sm font-medium text-brand hover:underline focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-brand"
        @click="emit('forgot')"
      >
        {{ AYLA_PIN_FORGOT }}
      </button>
    </div>
  </VaultSheet>
</template>
