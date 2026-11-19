<script setup lang="ts">
// "Pincode vergeten" without losing chats: first a code from the authenticator app (the same two-step code as at
// sign-in), then a new PIN. The database only accepts the new PIN after a code typed in the last five minutes.
// 'delete' is the other way out, for someone who cannot reach the authenticator: it deletes the locked chats.
const emit = defineEmits<{
  done: [];
  failed: [];
  close: [];
  deleteAll: [];
}>();

const lock = useAylaChatLock();
const { verifyCode } = useMfa();

const isOpen = ref(false);
const step = ref<'code' | 'pin'>('code');
const digits = ref('');
const error = ref<string | null>(null);
const isBusy = ref(false);
const fieldRef = useTemplateRef<{ focus: () => void }>('field');
const inputId = useId();
const errorId = useId();

async function checkCode(code: string) {
  isBusy.value = true;
  error.value = null;
  const { error: verifyError } = await verifyCode(code);
  isBusy.value = false;
  if (verifyError) {
    error.value = getAuthErrorMessage(verifyError);
    digits.value = '';
    fieldRef.value?.focus();
    return;
  }
  step.value = 'pin';
}

async function savePin(pin: string) {
  isBusy.value = true;
  const { isFailed } = await lock.recoverPin(pin);
  isBusy.value = false;
  emit(isFailed ? 'failed' : 'done');
}

onMounted(async () => {
  isOpen.value = true;
  await nextTick();
  fieldRef.value?.focus();
});
</script>

<template>
  <AylaPinDialog v-if="step === 'pin'" mode="create" is-change :is-busy="isBusy" @complete="savePin" @close="emit('close')" />
  <VaultSheet v-else v-model:open="isOpen" :title="ACCOUNT_PIN_VERIFY_TITLE" width="narrow" hides-title @close="emit('close')">
    <div class="flex flex-col items-center gap-5 pb-4 text-center">
      <span class="flex size-18 items-center justify-center rounded-full bg-tint text-brand" aria-hidden="true">
        <LayoutPaveIcon name="lock" class="size-8" />
      </span>
      <div class="-mt-1 flex flex-col gap-2">
        <p class="font-heading text-2xl font-semibold text-heading" aria-hidden="true">{{ ACCOUNT_PIN_VERIFY_TITLE }}</p>
        <p class="max-w-95 text-sm font-medium text-subtle">{{ ACCOUNT_PIN_VERIFY_BODY }}</p>
      </div>
      <div class="w-full">
        <label :for="inputId" class="sr-only">{{ ACCOUNT_PIN_CODE_LABEL }}</label>
        <LayoutCodeField
          :id="inputId"
          ref="field"
          v-model="digits"
          class="justify-center"
          :length="6"
          autocomplete="one-time-code"
          :is-disabled="isBusy"
          :is-invalid="Boolean(error)"
          :described-by="error ? errorId : undefined"
          @complete="checkCode"
        />
        <p v-if="error" :id="errorId" role="alert" class="mt-2 text-sm text-danger">{{ error }}</p>
      </div>
      <button
        type="button"
        class="text-sm font-medium text-danger hover:underline focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-brand"
        @click="emit('deleteAll')"
      >
        {{ ACCOUNT_PIN_DELETE_ALL }}
      </button>
    </div>
  </VaultSheet>
</template>
