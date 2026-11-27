<script setup lang="ts">
// Rejecting a verification request (iOS NotificationRejectSheet): the reviewer always writes why, so the learner knows
// what to fix before asking again.
const props = defineProps<{
  documentName: string;
  // Returns what went wrong, or null when the rejection is saved.
  onReject: (reason: string) => Promise<string | null>;
}>();

const isOpen = defineModel<boolean>('open', { required: true });

const MAX_LENGTH = 2000;
const formId = useId();
const fieldId = useId();
const hintId = useId();
const reason = ref('');
const isWorking = ref(false);
const errorMessage = ref<string | null>(null);

const cleanedReason = computed(() => reason.value.trim());
const canReject = computed(() => cleanedReason.value.length > 0 && !isWorking.value);

async function reject() {
  if (!canReject.value) return;
  isWorking.value = true;
  errorMessage.value = null;
  errorMessage.value = await props.onReject(cleanedReason.value);
  isWorking.value = false;
  if (!errorMessage.value) isOpen.value = false;
}

watch(isOpen, (open) => {
  if (!open) return;
  reason.value = '';
  errorMessage.value = null;
});
</script>

<template>
  <VaultSheet v-model:open="isOpen" :title="REJECT_TITLE" width="narrow">
    <form :id="formId" class="flex flex-col gap-2" @submit.prevent="reject">
      <label :for="fieldId" class="text-sm font-semibold text-heading">{{ REJECT_QUESTION(documentName) }}</label>
      <textarea
        :id="fieldId"
        v-model="reason"
        rows="5"
        :maxlength="MAX_LENGTH"
        :placeholder="REJECT_PLACEHOLDER"
        :aria-describedby="hintId"
        class="w-full resize-y rounded-field border border-field-line bg-white p-3 text-sm font-medium text-heading focus:border-brand focus:outline-none"
      />
      <p :id="hintId" class="text-xs text-subtle">{{ REJECT_EXPLANATION }}</p>
      <p v-if="errorMessage" role="alert" class="text-sm text-danger">{{ errorMessage }}</p>
    </form>

    <template #footer>
      <button
        type="button"
        :disabled="isWorking"
        class="min-h-10 min-w-25.75 rounded-field bg-field-line px-4 text-base font-medium text-heading hover:bg-tile focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-brand"
        @click="isOpen = false"
      >
        {{ AYLA_CANCEL }}
      </button>
      <button
        type="submit"
        :form="formId"
        :disabled="!canReject"
        class="min-h-10 min-w-25.75 rounded-field bg-danger px-4 text-base font-medium text-white hover:opacity-90 focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-brand disabled:opacity-50"
      >
        {{ isWorking ? REVIEW_WORKING : REJECT_CONFIRM }}
      </button>
    </template>
  </VaultSheet>
</template>
